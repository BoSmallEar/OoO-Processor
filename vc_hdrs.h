#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <dlfcn.h>
#include "svdpi.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _VC_TYPES_
#define _VC_TYPES_
/* common definitions shared with DirectC.h */

typedef unsigned int U;
typedef unsigned char UB;
typedef unsigned char scalar;
typedef struct { U c; U d;} vec32;

#define scalar_0 0
#define scalar_1 1
#define scalar_z 2
#define scalar_x 3

extern long long int ConvUP2LLI(U* a);
extern void ConvLLI2UP(long long int a1, U* a2);
extern long long int GetLLIresult();
extern void StoreLLIresult(const unsigned int* data);
typedef struct VeriC_Descriptor *vc_handle;

#ifndef SV_3_COMPATIBILITY
#define SV_STRING const char*
#else
#define SV_STRING char*
#endif

#endif /* _VC_TYPES_ */

void rob_print_header(int head, int tail, int commit_valid);
void rob_print_cycles();
void rob_print_input(int reset, int PC, int execution_finished, int dispatch_enable, int dest_areg_idx, int prf_free_preg_idx, int executed_rob_entry, int cdb_mis_pred);
void rob_print(int entry, int PC, int executed, int dest_areg, int dest_preg, int rob_mis_pred, int head, int tail);
void rob_print_close();

#ifdef __cplusplus
}
#endif

