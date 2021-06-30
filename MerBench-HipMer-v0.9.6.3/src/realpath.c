#include <stdlib.h>
#include <stdio.h>

int main(int argc, char **argv) {
  if (argc != 2) { 
     fprintf(stderr, "USAGE: realpath <pathname>\n");
     exit(1);
  }
  char *rp = realpath(argv[1], NULL);
  if (!rp) {
     fprintf(stderr, "Could not resolve the path to %s\n", argv[1]);
     exit(1);
  }
  printf("%s\n", rp);
  free(rp);
  exit(0);
}
