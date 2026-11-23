#include <ini.h>
#include <stdio.h>
#include <string.h>

static int read_answer(void *data, const char *section, const char *name, const char *value) {
    if (strcmp(section, "demo") || strcmp(name, "answer")) return 0;
    *(int *)data = strcmp(value, "42") == 0;
    return 1;
}

int main(void) {
    int found = 0;
    if (ini_parse_string("[demo]\nanswer=42\n", read_answer, &found) || !found) return 1;
    puts("42");
    return 0;
}
