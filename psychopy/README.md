Collection of Psychopy code here

Things to develop:
* drifting grating
* moving bar
* random sparse noise
* Full-filed charp (increasing temporal frequency)
* Full-field charp (increasing contrast)

Design principles
* Make each stimulus as a standalone function. Main function will setup monitor, logging file etc, and call stimulus functions sequentially.
* The main function will receive either keyboard input or TTL HIGH pulse through DLP-IO8-G to start the session.
* The code will generate TTL pulse at each frame?
    * or maybe at the start of a session (e.g. new direction in drifting gratings)
* Use Python 3.8 or later.
