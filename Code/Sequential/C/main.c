#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdbool.h>
#include <crypt.h>

#define WORD_SIZE 8 // word size
#define PASSWORD "6Melissa" // target password
#define SALT "PC" // 2 characters salt is needed to use DES in crypt() func
#define DICTIONARY "dict_1500000.txt"

int main() {

    printf("[*] target: %s\n", PASSWORD);
    printf("[*] salt: %s\n", SALT);

    char* encrypted = strdup(crypt(PASSWORD, SALT));
    printf("[*] encrypted string: %s\n", encrypted);

    printf("[*] iterating over dictionary...\n");
    FILE* dictionary;
    if((dictionary = fopen(DICTIONARY, "r")) == NULL) {
        fprintf(stderr, "[ⅹ] error: dictionary not found\n");
        exit (EXIT_FAILURE);
    }

    clock_t start = clock();

    bool found = false;
    size_t len = 0;
    char* current_word = (char*)malloc(WORD_SIZE * sizeof(char));
    char* current_word_encrypted = NULL;

    while ((getline(&current_word, &len, dictionary)) != -1) {
        //printf("[*] checking word: %s", current_word);

        current_word_encrypted = strdup(crypt(current_word, SALT));
        //printf("[*] encrypted word: %s\n", current_word_encrypted);

        if (strcmp(current_word_encrypted, encrypted) == 0) {
            printf("[✓] PASSWORD FOUND IN DICTIONARY: %s", current_word);
            clock_t end = clock();
            printf("[i] CPU time: %.5f seconds\n", (float)(end - start)/CLOCKS_PER_SEC);
            found = true;
            break;
        }
    }

    if (!found) {
        printf("[*] password not found in dictionary!\n");
    }

    printf("[*] Cleaning up...");

    fclose(dictionary);
    free(current_word);
    free(encrypted);
    free(current_word_encrypted);

    return 0;
}
