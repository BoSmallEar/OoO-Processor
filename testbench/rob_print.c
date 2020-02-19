
#include <stdio.h>
#include "DirectC.h"
 

static int cycle_count = 0;
static FILE* ppfile = NULL;


void rob_print_header(int head, int tail)
{
  if (ppfile == NULL)
    ppfile = fopen("rob.out", "w");
  fprintf(ppfile, "Header:\t\t%d\nTail:\t\t%d", head, tail);
  fprintf(ppfile, "Entry\t\tPC\t\tExecuted\t\tDest.ARN\t\tDest.PRN");
}

void rob_print_input(int clock, int PC, int dispatch_enable, int dest_areg_idx, int prf_free_preg_idx, int executed_rob_entry, int cdb_mis_pred)
{
    fprintf(ppfile, "clock:%d PC:%d dispatch_enable:%d dest_areg_idx:%d prf_free_preg_idx:%d executed_rob_entry:%d cdb_mis_pred:%d", clock, PC, dispatch_enable, dest_areg_idx, prf_free_preg_idx, executed_rob_entry, cdb_mis_pred);
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
    fprintf(ppfile, "%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d", entry, PC, executed, dest_areg, dest_preg, rob_mis_pred);
}
