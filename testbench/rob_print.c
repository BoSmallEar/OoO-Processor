
#include <stdio.h>
#include "DirectC.h"
 

static int cycle_count = 0;
static FILE* ppfile = NULL;


void rob_print_header(int head, int tail, int commit_valid)
{
  if (ppfile == NULL)
    ppfile = fopen("rob.out", "w");
  fprintf(ppfile, "Head:\t\t\t%-8d\nTail:\t\t\t%-8d\nCommit_valid:\t%-8d\n", head, tail, commit_valid);
  // fprintf(ppfile, "Entry\t\tPC\t\t\tExecuted\t\tDest.ARN\t\tDest.PRN\t\trob_mis_pred\n");
  fprintf(ppfile, "Entry\t|\tPC\t\t|\tExecuted\t|\tDest.ARN\t|\tDest.PRN\t|\trob_mis_pred\t|\n");
}

void rob_print_input(int reset, int PC, int execution_finished, int dispatch_enable, int dest_areg_idx, int prf_free_preg_idx, int executed_rob_entry, int cdb_mis_pred)
{

  if (ppfile != NULL)
    fprintf(ppfile, "reset:\t\t\t\t%d\nPC:\t\t\t\t\t%d\nexecution_finished:\t%d\ndispatch_enable:\t%d\ndest_areg_idx:\t\t%d\nprf_free_preg_idx:\t%d\nexecuted_rob_entry:\t%d\ncdb_mis_pred:\t\t%d\n", reset, PC, execution_finished, dispatch_enable, dest_areg_idx, prf_free_preg_idx, executed_rob_entry, cdb_mis_pred);
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

void rob_print(int entry, int PC, int executed, int dest_areg, int dest_preg, int rob_mis_pred, int head, int tail) 
{
  // if (ppfile != NULL) {
  //   fprintf(ppfile, "%-12d%-12d", entry, PC);

  //   if (executed == 0) fprintf(ppfile, "%-12s", "-");
  //   else fprintf(ppfile, "%-12s", executed);

  //   fprintf(ppfile, "%-12s%-12s", dest_areg, dest_preg);

  //   if (rob_mis_pred == 0) fprintf(ppfile, "%-12s", "-");
  //   else fprintf(ppfile, "%-12s", rob_mis_pred);

  //   if (head) fprintf(ppfile, "%-12s", "<- Head");
  //   if (tail) fprintf(ppfile, "%-12s", "<- Tail");

  if (ppfile != NULL) {
    fprintf(ppfile, "%-8d|\t%-8d|", entry, PC);

    if (executed == 0) fprintf(ppfile, "\t\t%-8s|", "-");
    else fprintf(ppfile, "\t\t%-8d|", executed);

    fprintf(ppfile, "\t\t%-8d|\t\t%-8d|", dest_areg, dest_preg);

    if (rob_mis_pred == 0) fprintf(ppfile, "\t\t%-12s|", "-");
    else fprintf(ppfile, "\t\t%-12d|", rob_mis_pred);

    if (head == entry) {
      if (tail == entry) fprintf(ppfile, "\t<- Head & Tail\n");
      else fprintf(ppfile, "\t<- Head\n");
    }
    else if (tail == entry) {
      fprintf(ppfile, "\t<- Tail\n");
    }
    else fprintf(ppfile, "\n");

    if (entry == 7) {
      fprintf(ppfile, "\n\n\n\n");
    }
    /*
    if (tail > head && entry > head && entry < tail) {
      fprintf(ppfile, "\tx");
    }
    if (tail < head && (entry > head || entry < tail)) {
      fprintf(ppfile, "\tx");
    }
    */
    // fprintf(ppfile, "%-12d%-12d%-12d%-12d\n", executed, dest_areg, dest_preg, rob_mis_pred);
  }
}
