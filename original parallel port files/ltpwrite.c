/*
 * function lptwrite(port, value)
 * % LPTWRITE write byte to port
 * %
 * % Description:
 * % IOCTL call to porttalk.sys kernel mode driver (required) by Craig
 * % Peacock
 * %
 * % Usage:
 * % lptwrite(port, value)
 * %
 * % Arguments:
 * % port - double Port address (e.g., 888 = 0x378 for LPT1 on many
 * % machines)
 * % value - double value to write (0-255)
 * %
 * % Examples:
 * % lptwrite(888, 42);
 * %
 * % Author: Andreas Widmann, University of Leipzig, 2006
 *
 * % PortTalk functions and driver:
 * % Copyright (C) 1999-2002 Craig Peacock, http://www.beyondlogic.org
 * %
 * % Copyright (C) 2006 Andreas Widmann, University of Leipzig, widmann@...
 * %
 * % This program is free software; you can redistribute it and/or modify
 * % it under the terms of the GNU General Public License as published by
 * % the Free Software Foundation; either version 2 of the License, or
 * % (at your option) any later version.
 * %
 * % This program is distributed in the hope that it will be useful,
 * % but WITHOUT ANY WARRANTY; without even the implied warranty of
 * % MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * % GNU General Public License for more details.
 * %
 * % You should have received a copy of the GNU General Public License
 * % along with this program; if not, write to the Free Software
 * % Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307,
 * % USA
 *
 *
 * % http://groups.yahoo.com/group/psychtoolbox/message/4825
 */

/*
 * lptwrite.c
 *
 * Compile in MATLAB with mex lptwrite.c [-O] [-g] [-v]
 * For description see lptwrite.m
 *
 * Copyright (C) 2006 Andreas Widmann, University of Leipzig,
 * widmann@...
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

#include "stdio.h"
#include "windows.h"
#include "mex.h"
#include "pt_ioctl.c"

void __cdecl mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray
        *prhs[])
{
    double *port, *value;
    int mrows, ncols, arg;
    
    /* Check for proper number of arguments. */
    if (nrhs != 2) {
        mexErrMsgTxt("Two input arguments required.");
    } else if (nlhs > 0) {
        mexErrMsgTxt("Too many output arguments.");
    }
    
    /* The input must be noncomplex scalar double.*/
    for (arg = 0; arg < 2; arg++) {
        mrows = mxGetM(prhs[arg]);
        ncols = mxGetN(prhs[arg]);
        if (!mxIsDouble(prhs[arg]) || mxIsComplex(prhs[arg]) || !(mrows == 1 &&
                ncols == 1)) {
            mexErrMsgTxt("Input must be noncomplex scalar double.");
        }
    }
    
    /* Assign pointers to each input and output. */
    port = mxGetData(prhs[0]);
    value = mxGetData(prhs[1]);
    
    OpenPortTalk();
    outportb(*port, *value);
    ClosePortTalk();
}
