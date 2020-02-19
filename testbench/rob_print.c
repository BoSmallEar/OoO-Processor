
#include <stdio.h>
#include "DirectC.h"
 

static int cycle_count = 0;
static FILE* ppfile = NULL;


void rob_print_header(int head, int tail, int commit_valid)
{
  if (ppfile == NULL)
    ppfile = fopen("rob.out", "w");
  fprintf(ppfile, "Header:\t\t%d\nTail:\t\t%d\nCommit_valid:\t\t%d\n", head, tail, commit_valid);
  fprintf(ppfile, "Entry\t\tPC\t\tExecuted\tDest.ARN\tDest.PRN\trob_mis_pred\n");
}

void rob_print_input(int reset, int PC, int execution_finished, int dispatch_enable, int dest_areg_idx, int prf_free_preg_idx, int executed_rob_entry, int cdb_mis_pred)
{

  if (ppfile != NULL)
    fprintf(ppfile, "reset:\t%d \nPC:\t%d \nexecution_finished:\t%d \ndispatch_enable:\t%d \ndest_areg_idx:\t%d \nprf_free_preg_idx:\t%d \nexecuted_rob_entry:\t%d \ncdb_mis_pred:\t%d\n\n\n\n\n", reset, PC, execution_finished, dispatch_enable, dest_areg_idx, prf_free_preg_idx, executed_rob_entry, cdb_mis_pred);
}

void rob_print_cycles()
{
  /* we'll enforce the printing of a header */
  if (ppfile != NULL)
    fprintf(ppfile, "\n%5d:", cycle_count++);
}


void rob_print_close()
{
  fprintf(ppfile, "\n");
  fclose(ppfile);
  ppfile = NULL;
}

void rob_print(int entry, int PC, int executed, int dest_areg, int dest_preg, int rob_mis_pred) 
{
  if (ppfile != NULL)
    fprintf(ppfile, "%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\n", entry, PC, executed, dest_areg, dest_preg, rob_mis_pred);
}
