#include <iostream>
#include <string>
#include <vector>
#include <unistd.h>
#include "Decrypter.h"

using namespace std;

#define DICTIONARY "dict_1500000.txt"

int main(int argc, char** argv) {

    string password = "6Melissa";
    string salt = "PC"; // 2 characters salt is needed to use DES in r_crypt() func

    cout << "[*] TARGET: " << password << endl;
    cout << "[*] SALT: " << salt << endl;

    vector<int> nThreads = {2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096};

    try {
        Decrypter d(DICTIONARY, password, salt);
        for (int threads : nThreads) {
            cout << "[*] --- Results using " << threads << " threads:" << endl;
            d.decrypt(threads);
            usleep(2000000); // wait 2s
        }
    } catch (runtime_error &e) {
        std::cerr << "Caught exception: " << e.what() << endl;
    }
}
