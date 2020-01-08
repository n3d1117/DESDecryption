#include <chrono>
#include <fstream>
#include <iostream>
#include <string>
#include <unistd.h>
#include <cstring>
#include <crypt.h>
#include <omp.h>
#include "Decrypter.h"

using namespace std;

Decrypter::Decrypter(const string& dictionaryPath, const string& password, const string& salt) {
    this->salt = salt;
    this->encrypted = strdup(crypt(password.c_str(), salt.c_str()));

    cout << "[*] Encrypted password: " << this->encrypted << "\n" << endl;

    string line;
    ifstream dictionary(dictionaryPath);

    if (!dictionary) {
        throw runtime_error("Could not open file!");
    }

    while (getline(dictionary, line)) {
        fullDictionary.push_back(line);
    }

    dictionary.close();
}

void Decrypter::decrypt(int threads) {

    volatile bool found = false;
    auto start = chrono::steady_clock::now();

#pragma omp parallel num_threads(threads)
    {
        struct crypt_data data;
        data.initialized = 0;

        //cout << "[i] Thread num: " << omp_get_thread_num() << endl;

#pragma omp for
        for (int i = 0; i < fullDictionary.size(); i++) {
            if (found) continue;

            char *current_word_encrypted = crypt_r(fullDictionary[i].c_str(), salt.c_str(), &data);

            if (strcmp(current_word_encrypted, encrypted.c_str()) == 0) {
                cout << "[✓] PASSWORD FOUND IN DICTIONARY: " << fullDictionary[i] << endl;
                found = true;
            }
        }
    }

    if (found) {
        auto end = chrono::steady_clock::now();
        std::chrono::duration<double> elapsedSeconds = end - start;
        cout << "[i] CPU Time: " << elapsedSeconds.count() << " seconds\n" <<  endl;
    } else {
        cout << "[*] Password not found in dictionary!\n" << endl;
    }
}
