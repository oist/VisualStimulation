import struct, logging, asyncio
from threading import Thread, Lock
from functools import partial
from enum import IntEnum
import re
from time import sleep

import serial
from serial.tools import list_ports

__version__ = "1.2.0"

class ELLStatus(IntEnum):
    """
    Status codes and descriptions returned by Thorlabs Elliptec devices.

    These codes are the same as documented in the communications protocol document from Thorlabs.
    """
    OK = 0
    COMM_TIMEOUT = 1
    MECH_TIMEOUT = 2
    COMMAND_NOT_SUPPORTED = 3
    VALUE_OUT_OF_RANGE = 4
    MODULE_ISOLATED = 5
    MODULE_NOT_ISOLATED = 6
    INIT_ERROR = 7
    THERMAL_ERROR = 8
    BUSY = 9
    SENSOR_ERROR = 10
    MOTOR_ERROR = 11
    OUT_OF_RANGE = 12
    OVER_CURRENT = 13
    UNKNOWN = 14

    @property
    def description(self):
        """
        Get a string representation of this status code.
        """
        return ["ok",
                "communication timeout",
                "mechanical timeout",
                "command not supported",
                "value out of range",
                "module isolated",
                "module out of isolation",
                "initialisation error",
                "thermal error",
                "busy",
                "sensor error",
                "motor error",
                "out of range",
                "over current",
                "unknown"][self.value]
    
    def __str__(self):
        return f"{self.name} ({self.value}) {self.description}"


class ELLError(Exception):
    """
    Exception class to indicate an error with the Elliptec device.
    
    The optional parameter is an instance of :data:`ELLStatus` to describe the error type.

    An instance of this exception may be raised from movement commands (e.g.
    :meth:`~thorlabs_elliptec.ELLx.move_absolute`, :meth:`~thorlabs_elliptec.ELLx.move_relative`,
    :meth:`~thorlabs_elliptec.ELLx.home`) when used in synchronous mode by passing
    ``blocking=True``. When using (the default, non-blocking) asynchronous mode, an exception may be
    raised from :meth:`~thorlabs_elliptec.ELLx.is_moving` or :meth:`~thorlabs_elliptec.ELLx.wait` if
    the ``raise_errors=True`` parameter is passed.

    :param status: :data:`ELLStatus` object to describe the error.
    """
    def __init__(self, status:ELLStatus=ELLStatus.UNKNOWN):
        #: A instance of :data:`ELLStatus` which describes the error.
        self.status = status
    
    def __str__(self):
        return f"ELLError ({self.status.value}) {self.status.description}"


class ELLx():
    """
    Generic class to interact with the Thorlabs Elliptec series of devices.

    The ``serial_port`` parameter may be a system-specific string (eg. ``"/dev/ttyUSB0"``,
    ``"COM12"``) or a :data:`serial.tools.list_ports_common.ListPortInfo` instance. If the
    ``serial_port`` parameter is ``None`` (default), then an attempt to detect a serial device will
    be performed. The first device found will be initialised. If multiple serial devices are present
    on the system, then the use of the the additional keyword arguments can be used to select a
    specific device. The keyword arguments the same as those used for :meth:`find_device`.

    The multi-drop feature of the ELLx devices may be used by specifying an existing instance of an
    ELLx class as the ``serial_port`` parameter. The serial port device initialised by the existing
    instance will be shared with the newly created one.

    The default parameter of ``x=None`` will result in the specific model of ELLx device to be
    automatically detected. If a number is specified (eg. ``x=20`` for an ELL20), then an exception
    will be raised if the detected model number does not match.

    The default parameter of ``device_serial=None`` will use any detected device, regardless of its
    serial number. If a device serial string is specified, an exception will be raised if the
    detected serial number does not match.

    The Elliptec devices support a "multi drop" bus arrangement on the serial port lines, which
    allows control of multiple devices over a single serial link. The ``device_id`` parameter should
    correspond to the device ID number programmed into the device. For single devices on a serial
    port, the default of ``0`` is probably correct. Changing a device ID through this library is not
    currently supported. Use a serial terminal program (e.g. minicom or putty) to connect to a
    device and issue the "change address" command. For example, ``0ca1`` will change the device ID
    from 0 to 1. The "save user data" (``us``) command might also be needed to make the address
    change permanent. See the Thorlabs documentation on the `Elliptec serial communication protocol
    <https://www.thorlabs.com/Software/Elliptec/Communications_Protocol/ELLx%20modules%20protocol%20manual_Issue7.pdf>`__
    for more details.

    The remaining keyword arguments are passed onto :meth:`find_device` for selection of a specific
    serial port device.

    :param serial_port: Serial port device the device is connected to, or another instance of the
        ELLx class.
    :param x: The required "x" in the detected ELLx model number.
    :param device_serial: Serial number required of the detected device.
    :param device_id: Numeric ID to use during serial communications with device.
    :param vid: Serial port numerical USB vendor ID to match.
    :param pid: Serial port numerical USB product ID to match.
    :param manufacturer: Serial port regular expression to match to a device manufacturer string.
    :param product: Serial port regular expression to match to a device product string.
    :param serial_number: Serial port regular expression to match to a device serial number.
    :param location: Serial port regular expression to match to a device physical location.
    """

    # ELLx device model numbers of linear translation stages.
    _LINEAR_STAGES = (7, 10, 17, 20)
    # ELLx device model numbers of rotation stages.
    _ROTATION_STAGES = (8, 14, 18)
    # ELLx device model numbers of multi-position shutters.
    _SHUTTERS = (6, 9)

    def __init__(self, serial_port=None, x:int=None, device_serial:str=None, device_id:int=0, **kwargs):

        # If serial_port not specified, search for a device
        if serial_port is None:
            serial_port = find_device(**kwargs)
        # Accept a serial.tools.list_ports.ListPortInfo object (which we may have just found)
        if isinstance(serial_port, serial.tools.list_ports_common.ListPortInfo):
            serial_port = serial_port.device
        if serial_port is None:
            raise RuntimeError("No devices detected matching the selected criteria.")

        # Model number of this device. This is the "x" part in ELLx, such as "20" for an ELL20
        if not x is None:
            self._x = int(x)
        else:
            self._x = None
        
        # Serial number of this device
        if not device_serial is None:
            # If specified, check and require to be correct during initialisation
            self._serial_number = str(device_serial)
        else:
            # Populate during the ID query
            self._serial_number = None

        # Fields populated during ID query
        # Pulses per measurement unit
        self._pp = 1
        # Maximum travel distance of device
        self._travel = 1

        # Device ID number to use during serial communications for this device
        self._device_id = int(device_id)

        # Current status of device, as a :class:`ELLStatus` enum.
        self._status = ELLStatus.UNKNOWN
        # Current position of device, in encoder steps.
        self._position = 0.0
        # Manufacturing year
        self._year = 0
        # Firmware version
        self._firmware_version = ""
        # Metric or imperial thread types
        self._thread_type = ""

        # Flag to indicate movement in progress
        self._moving = False

        self._log = logging.getLogger(__name__)

        #: Time in seconds to wait for the lock on the serial port device when shared with other
        #: devices in a multi-drop configuration.
        self.port_lock_timeout = 10.0

        if isinstance(serial_port, ELLx):
            self._log.debug(f"Sharing serial port ({serial_port}).")
            # If serial_port an instance of another ELLx class, steal it's reference to the serial port
            self._port = serial_port._port
            # Increment the count of devices sharing the serial port
            self._port.device_count += 1
        else:

            self._log.debug(f"Initialising serial port ({serial_port}).")
            # Open and configure the serial port settings for Thorlabs ELLx devices
            self._port = serial.Serial(port=serial_port,
                                    baudrate=9600,
                                    parity=serial.PARITY_NONE,
                                    stopbits=serial.STOPBITS_ONE,
                                    bytesize=serial.EIGHTBITS,
                                    timeout=10.0,
                                    write_timeout=1.0)
            # Create a lock for the serial port to ensure single device access at any one time
            # Rudely store the references inside the Serial instance...
            self._port.lock = Lock()
            # Store a counter of number of devices sharing the serial port
            self._port.device_count = 1
        
        # Query device information, check if actually a ELLx device
        self._query()
        
        # Create a new event loop for ourselves, running in a separate thread
        self._eventloop = asyncio.new_event_loop()
        self._thread = Thread(target=self._run_eventloop, daemon=True)
        self._thread.start()
        # Status polling interval, in seconds.
        self._status_poll_interval = 0.1
        # Queue first status update, store task handle
        self._updatehandle = self._eventloop.call_soon_threadsafe(self._update_status)


    @property
    def port_name(self) -> str:
        """
        Serial port device name.
        
        The naming is dependent on the underlying operating system, for example ``"/dev/ttyUSB1"``
        on Linux or ``"COM5"`` on Windows.
        """
        return self._port.name


    @property
    def units(self) -> str:
        """
        A string representation of the units for the device's movement type.

        For linear stages this will be ``"mm"``, or ``"°"`` for rotation stages.
        """
        if self._x in ELLx._LINEAR_STAGES:
            return "mm"
        elif self._x in ELLx._ROTATION_STAGES:
            return "°"
        else:
            return ""


    @property
    def model_number(self) -> str:
        """
        Model number of the device.

        Metric thread versions will include their "/M" suffix. Example model numbers are
        ``"ELL14/M"`` or ``"ELL18"``.
        """
        return f"ELL{self._x}{'/M' if self._thread_type == 'metric' else ''}"


    @property
    def device_id(self) -> int:
        """
        Numeric ID of the device used during communications.
        """
        return self._device_id


    @property
    def serial_number(self) -> str:
        """
        Serial number of the device.
        """
        return self._serial_number


    @property
    def travel(self) -> int:
        """
        Maximum travel distance/angle of device.
        """
        return self._travel
    

    @property
    def year(self) -> int:
        """
        Manufacturing year of the device.
        """
        return self._year
    

    @property
    def firmware_version(self) -> str:
        """
        Firmware version installed on the device.
        """
        return self._firmware_version
    

    @property
    def thread_type(self) -> str:
        """
        Thread type of mountings on the device (``"metric"`` or ``"imperial"``).
        """
        return self._thread_type
    

    @property
    def status_poll_interval(self) -> float:
        """
        Time between polling for status updates, in seconds. Default is 0.1 seconds.
        """
        return self._status_poll_interval
    
    @status_poll_interval.setter
    def status_poll_interval(self, value:float):
        self._status_poll_interval = float(value)


    @property
    def status(self):
        """
        Current state of the ELLx device. The return type is in instance of the :class:`ELLStatus`
        enum.
        """
        return self._status


    @property
    def _pp_string(self):
        """
        Helper for string to use in "pulses per ..." reports.
        """
        if self._x in ELLx._LINEAR_STAGES:
            return "mm:         "
        elif self._x in ELLx._ROTATION_STAGES:
            return "revolution: "
        else:
            return "position:   "
    

    @property
    def _revolution(self):
        """
        Helper for factor to convert revolution to degrees. Equal to 360.0 for rotation stages, or
        1.0 for others.
        """
        if self._x in ELLx._ROTATION_STAGES:
            return 360.0
        else:
            return 1.0
    

    def _query(self):
        """
        Query device ID, wait for response.
        """
        self._log.debug("Querying ELLx information.")
        reply_data = self._write_command("in")
        
        # 33 byte reply from ELLx should start by echoing IN request
        if len(reply_data) != 33 or reply_data[0:3] != f"{self._device_id:01X}IN":
            raise Exception(f"Could not query ELLx information! (response was '{reply_data}')")
        
        # Get ELLx model reported in reply
        x = int(reply_data[3:5], 16)
        if not self._x is None:
            # If a specific model is given, check this matches up.
            if x != self._x:
                raise RuntimeError(f"Device is not an ELL{self._x}! (device reported to be an ELL{x})")
        else:
            # Otherwise, set model from reported value
            self._x = x

        # Get serial number reported in reply
        sn = reply_data[5:13]
        if not self._serial_number is None:
            # If serial number given, check it matches
            if sn != self._serial_number:
                raise RuntimeError(f"Device does not have expected serial number '{self._serial_number}'! (device reported '{sn}')")
        else:
            # Otherwise, set serial number from reported value
            self._serial_number = sn

        # Manufacturing year
        self._year = int(reply_data[13:17])
        # Firmware version
        self._firmware_version = reply_data[17:19]
        # Travel distance
        self._travel = int(reply_data[21:25], 16)
        # Metric or imperial thread type
        self._thread_type = "imperial" if int(reply_data[19:21], 16) & 0x80 else "metric"
        # Pulses per mm/revolution
        self._pp = int(reply_data[25:33], 16)
        
        self._log.info(f"ELLx serial port:       {self._port.name}")
        self._log.info(f"ELLx type:              {self._x}")
        self._log.info(f"Serial number:          {self._serial_number}")
        self._log.info(f"Manufacturing year:     {self._year}")
        self._log.info(f"Firmware version:       {self._firmware_version}")
        self._log.info(f"Thread type:            {self._thread_type}")
        self._log.info(f"Travel:                 {self._travel}{self.units}")
        self._log.info(f"Pulses per {self._pp_string} {self._pp}")

        return reply_data


    def _run_eventloop(self):
        """
        Run the thread for the event loop.
        """
        self._log.debug("Starting event loop.")
        asyncio.set_event_loop(self._eventloop)
        try:
            self._eventloop.run_forever()
        finally:
            self._eventloop.close()
        self._log.debug("Event loop stopped.")
        if self._port:
            # Decrement the count of devices sharing the serial port
            self._port.device_count -= 1
            self._log.debug(f"Remaining devices sharing the serial port = {self._port.device_count}")
        if self._port and self._port.is_open and self._port.device_count <= 0:
            # If no other devices using the serial port then we can close it
            self._log.debug("Closing serial connection.")
            try:
                self._port.close()
            except:
                self._log.debug("Error closing serial port.")


    def _update_status(self):
        """
        Query the current state of the ELLx device, and update the cached status code.
        """
        self._log.debug("Querying device status.")
        reply_data = self._write_command("gs")

        # Should echo GS request
        if len(reply_data) == 5 and reply_data[0:3] == f"{self._device_id:01X}GS":
            self._status = ELLStatus(int(reply_data[3:5], 16))
            if not self._status == ELLStatus.OK:
                # Some non-standard state was returned, emit warning
                self._log.warning(f"Device #{self._device_id} reported status {self._status} = {self._status.description}")
        else:
            self._status = ELLStatus.UNKNOWN
            self._log.warning(f"Could not query device status! (response was '{reply_data}')")
        
        self._log.debug("Querying device position.")
        reply_data = self._write_command("gp")
        # Should return position data
        if len(reply_data) == 11 and reply_data[0:3] == f"{self._device_id:01X}PO":
            self._position = struct.unpack(">i", bytes.fromhex(reply_data[3:11]))[0]
        else:
            self._log.warning(f"Could not query device position! (response was '{reply_data}')")
        
        self._updatehandle = self._eventloop.call_later(self._status_poll_interval, self._update_status)


    def _write_command(self, command_string):
        """
        Write a command out the the serial port, wait for response and return the received string.
        
        The device ID will be prepended, and a CRLF appended to the given command_string.
        """
        indata = ""
        # Acquire the lock on the serial port
        if not self._port.lock.acquire(blocking=True, timeout=self.port_lock_timeout):
            self._log.warning(f"Timeout waiting for lock on serial port (another device busy?)")
        else:
            request_data = f"{self._device_id:01X}{command_string}"
            self._log.debug(f"Writing command string: {request_data}")
            self._port.write(bytearray(request_data + "\r\n", "ascii"))
            self._port.flush()
            while indata[-2:] != "\r\n":
                try:
                    inbytes = self._port.read(1)
                except serial.SerialException as ex:
                    self._log.warning(f"Error reading response string! (requested '{request_data}', received '{indata}')")
                    break
                if len(inbytes) > 0:
                    indata += inbytes.decode("ascii")
                else:
                    self._log.warning(f"Timeout reading response string! (requested '{request_data}', received '{indata}')")
                    break
            # Release lock on serial port so other devices can communicate
            self._port.lock.release()
        reply_data = indata.rstrip("\r\n")
        self._log.debug(f"Response string: {reply_data}")
        return reply_data


    def close(self) -> None:
        """
        Close the serial connection to the ELLx device.

        Note that this method returns immediately, and the halting of communications and closing of
        the serial port is performed in a background thread. This means the serial port may not
        actually be closed yet when this method returns.

        Further, if the multi-drop feature of the ELLx devices is used, the serial port will only be
        closed if no other devices remain open which are sharing the same serial port device.
        """
        self._log.debug("Cancelling scheduled status update handle.")
        self._updatehandle.cancel()   
        self._log.debug("Stopping event loop.")
        self._eventloop.stop()


    def get_position_raw(self) -> int:
        """
        Return the current position of the ELLx device, in raw encoder counts.

        :returns: Position in raw encoder counts.
        """
        return self._position


    def get_position(self) -> float:
        """
        Return the current position of the ELLx device, in real device units.

        :returns: Position in real device units.
        """
        return round(self._revolution*self._position/self._pp, 3)


    def _move(self, command_string, command_name="move"):
        """
        Perform a generic movement (home, relative, absolute) and handle the response.
        
        This should only be called from within the event loop thread.
        """
        self._log.debug(f"Requesting a {command_name}.")
        # Flag that movement should (soon) be in progress
        self._moving = True
        try:
            reply_data = self._write_command(command_string)
            # Will reply with status message if something went wrong, else will return position
            if len(reply_data) == 5 and reply_data[0:3] == f"{self._device_id:01X}GS":
                self._status = ELLStatus(int(reply_data[3:5], 16))
                if self._status == ELLStatus.OK:
                    # Don't think device should return OK, but fine if it does...
                    self._moving = False
                else:
                    # Something went wrong, set move flag to error state
                    self._moving = ELLError(self._status)
            elif len(reply_data) == 11 and reply_data[0:3] == f"{self._device_id:01X}PO":
                # Flag movement now complete
                self._moving = False
                self._position = struct.unpack(">i", bytes.fromhex(reply_data[3:11]))[0]
            else:
                self._log.warning(f"Could not perform {command_name}! (response was '{reply_data}')")
                # Something went wrong, set move flag to error state
                self._moving = ELLError(ELLStatus.UNKNOWN)
        except:
            self._log.exception(f"Exception attempting to perform {command_name}!")
            # Some error parsing reply or other error, make sure we set the move flag appropriately
            self._moving = ELLError(ELLStatus.UNKNOWN)
            # May not want to raise exception up through the background thread?
            #raise


    def _home(self, direction:int=0):
        """
        Home the device.
        
        This should only be called from within the event loop thread.
        """
        self._move(command_string=f"ho{int(bool(direction))}", command_name="homing operation")


    def home(self, direction:int=0, blocking:bool=False) -> None:
        """
        Move to device to the home position.

        The direction of movement (e.g. for rotational stages) can be configured using the ``direction`` parameter.
        This parameter should be ``0`` or ``1``, but ``True`` or ``False`` are also valid.

        The default behaviour is for this method to return immediately, without waiting for the
        operation to complete (or to detect any movement errors). To instead wait for the operation
        to finish, set the parameter ``blocking=True``. If a movement error occurs, an
        :data:`ELLError` will be raised.

        :param direction: Direction to move.
        :param blocking: Wait for operation to complete.
        """
        # Flag movement should begin soon
        self._moving = True
        self._eventloop.call_soon_threadsafe(partial(self._home, direction=direction))
        if blocking:
            self.wait(raise_errors=True)


    def _move_absolute_raw(self, counts):
        """
        Perform a move to an absolute position, in raw encoder counts.

        This should only be called from within the event loop thread.
        """
        self._move(command_string=f"ma{int(counts) & 0xffffffff:08X}", command_name="absolute move")


    def _move_relative_raw(self, counts):
        """
        Perform a move by a relative amount, in raw encoder counts.

        This should only be called from within the event loop thread.
        """
        self._move(command_string=f"mr{int(counts) & 0xffffffff:08X}", command_name="relative move")


    def move_absolute_raw(self, counts:int, blocking:bool=False) -> None:
        """
        Move the device to an absolute position, specified in raw encoder counts.

        The default behaviour is for this method to return immediately, without waiting for the
        operation to complete (or to detect any movement errors). To instead wait for the operation
        to finish, set the parameter ``blocking=True``. If a movement error occurs, an
        :data:`ELLError` will be raised.

        :param counts: Position to move to, in raw encoder counts.
        :param blocking: Wait for operation to complete.
        """
        # Flag movement should begin soon
        self._moving = True
        self._eventloop.call_soon_threadsafe(self._move_absolute_raw, counts)
        if blocking:
            self.wait(raise_errors=True)


    def move_absolute(self, position:float, blocking:bool=False) -> None:
        """
        Move the device to an absolute position, specified in real device units.

        The default behaviour is for this method to return immediately, without waiting for the
        operation to complete (or to detect any movement errors). To instead wait for the operation
        to finish, set the parameter ``blocking=True``. If a movement error occurs, an
        :data:`ELLError` will be raised.

        :param position: Position to move to, in real device units.
        :param blocking: Wait for operation to complete.
        """
        self.move_absolute_raw(self._pp*position/self._revolution, blocking=blocking)


    def move_relative_raw(self, counts:int, blocking:bool=False) -> None:
        """
        Move the device by a relative amount, specified in raw encoder counts.

        The default behaviour is for this method to return immediately, without waiting for the
        operation to complete (or to detect any movement errors). To instead wait for the operation
        to finish, set the parameter ``blocking=True``. If a movement error occurs, an
        :data:`ELLError` will be raised.

        :param counts: Amount to move by, in raw encoder counts.
        :param blocking: Wait for operation to complete.
        """
        # Flag movement should begin soon
        self._moving = True
        self._eventloop.call_soon_threadsafe(self._move_relative_raw, counts)
        if blocking:
            self.wait(raise_errors=True)


    def move_relative(self, amount:float, blocking:bool=False) -> None:
        """
        Move the device by a relative amount, specified in real device units.

        The default behaviour is for this method to return immediately, without waiting for the
        operation to complete (or to detect any movement errors). To instead wait for the operation
        to finish, set the parameter ``blocking=True``. If a movement error occurs, an
        :data:`ELLError` will be raised.

        :param amount: Amount to move by, in real device units.
        :param blocking: Wait for operation to complete.
        """
        self.move_relative_raw(self._pp*amount/self._revolution, blocking=blocking)


    def is_moving(self, raise_errors:bool=False) -> bool:
        """
        Test if the device is currently performing a move operation.

        By default, if a movement error occurs, this method will ignore the fault and simply return
        ``False``. To instead raise an :data:`ELLError` exception, set the parameter
        ``raise_errors=True``.

        :param raise_errors: Raise an :data:`ELLError` if movement failed.

        :returns: True if device is currently moving.
        """
        if isinstance(self._moving, ELLError):
            if raise_errors:
                raise self._moving
            else:
                return False
        return bool(self._moving)


    def wait(self, raise_errors:bool=False) -> None:
        """
        Block until any current movement is completed.

        By default, if a movement error occurs, this method will ignore the fault and return
        silently. To instead raise an :data:`ELLError` exception, set the parameter
        ``raise_errors=True``.

        :param raise_errors: Raise an :data:`ELLError` if movement failed.
        """
        while True:
            if not self.is_moving(raise_errors=raise_errors):
                return
            sleep(0.01)


def find_device(vid:int=None, pid:int=None, manufacturer:str=None, product:str=None, serial_number:str=None, location:str=None):
    """
    Search attached serial ports for a specific device.

    The first device found matching the criteria will be returned.
    Because there is no consistent way to identify serial devices, the default parameters do not
    specify any selection criteria, and thus the first serial port will be returned.
    A specific device should be selected using a unique combination of the parameters.

    The USB vendor (``vid``) and product (``pid``) IDs are exact matches to the numerical values,
    for example ``vid=0x067b`` or ``vid=0x2303``. The remaining parameters are strings specifying a
    regular expression match to the corresponding field. For example ``serial_number="83"`` would
    match devices with serial numbers starting with 83, while ``serial_number=".*83$"`` would match
    devices ending in 83. A value of ``None`` means that the parameter should not be considered,
    however an empty string value (``""``) is subtly different, requiring the field to be present,
    but then matching any value.

    Be aware that different operating systems may return different data for the various fields, 
    which can complicate matching when attempting to write cross-platform code.

    To see a list of serial ports and the relevant data fields:

    .. code-block: python

        import serial
        for p in list_ports.comports():
            print(f"{p.device}, {p.manufacturer}, {p.product}, {p.vid}, {p.pid}, {p.serial_number}, {p.location}")

    :param vid: Numerical USB vendor ID to match.
    :param pid: Numerical USB product ID to match.
    :param manufacturer: Regular expression to match to a device manufacturer string.
    :param product: Regular expression to match to a device product string.
    :param serial_number: Regular expression to match to a device serial number.
    :param location: Regular expression to match to a device physical location (eg. USB port).
    :returns: First :class:`~serial.tools.list_ports.ListPortInfo` device which matches given criteria.
    """
    for p in list_ports.comports():
        if (vid is not None) and not vid == p.vid: continue
        if (pid is not None) and not pid == p.pid: continue
        if (manufacturer is not None) and ((p.manufacturer is None) or not re.match(manufacturer, p.manufacturer)): continue
        if (product is not None) and ((p.product is None) or not re.match(product, p.product)): continue
        if (serial_number is not None) and ((p.serial_number is None) or not re.match(serial_number, p.serial_number)): continue
        if (location is not None) and ((p.location is None) or not re.match(location, p.location)): continue
        return p


def list_devices() -> str:
    """
    Return a string listing all detected serial devices and any associated identifying properties.

    The manufacturer, product, vendor ID (vid), product ID (pid), serial number, and physical
    device location are provided.
    These can be used as parameters to :meth:`find_device` or the constructor of a device class
    to identify and select a specific serial device.

    :returns: String listing all serial devices and their details.
    """
    result = ""
    for p in list_ports.comports():
        try:
            vid = f"{p.vid:#06x}"
            pid = f"{p.pid:#06x}"
        except:
            vid = p.vid
            pid = p.pid
        result += f"device={p.device}, manufacturer={p.manufacturer}, product={p.product}, vid={vid}, pid={pid}, serial_number={p.serial_number}, location={p.location}\n"
    return result.strip("\n")
