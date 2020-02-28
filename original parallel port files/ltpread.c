/*
lptread.c
 
Compile in MATLAB with mex lptread.c [-O] [-g] [-v] 
*/

#include "stdio.h"
#include "windows.h"
#include "mex.h"
#include "pt_ioctl.c"

void __cdecl mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    double *port;
    int mrows, ncols;
    double *val;
    
/* Check for proper number of arguments. */
    if (nrhs != 1) {
        mexErrMsgTxt("One input argument required.");
    } else if (nlhs != 1) {
        mexErrMsgTxt("One output argument required.");
    }
    
/* The input must be noncomplex scalar double.*/
    mrows = mxGetM(prhs[0]);
    ncols = mxGetN(prhs[0]);
    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0]) || !(mrows == 1 && ncols == 1)) {
        mexErrMsgTxt("Input must be noncomplex scalar double.");
    }
    
/* Assign pointers to the input. */
    port = mxGetData(prhs[0]);
    plhs[0] = mxCreateScalarDouble(0);
    val = mxGetPr(plhs[0]);
    
    OpenPortTalk();
    *val = inportb(*port);
    ClosePortTalk();    
}
