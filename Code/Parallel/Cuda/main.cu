#include <iostream>
#include <numeric>
#include <stdlib.h>
#include <inttypes.h>
#include "des/des.h"
#include "utils.cuh"

#define WORD_SIZE 8 // word size
#define DICTIONARY "dict_1500000.txt"
#define DICTIONARY_SIZE 1500000

// Load full dictionary into memory
uint64_t *populateDictionary() {
	uint64_t *data = (uint64_t*)malloc(sizeof(uint64_t) * DICTIONARY_SIZE);
	FILE* dictionary;
	if((dictionary = fopen(DICTIONARY, "r")) == NULL) {
		fprintf(stderr, "[ⅹ] error: dictionary not found\n");
		exit (EXIT_FAILURE);
	}
	size_t len = 0;
	char* current_word = (char*)malloc(WORD_SIZE * sizeof(char));
	int i = 0;
	while ((getline(&current_word, &len, dictionary)) != -1) {
		//printf("[*] current word: %s", current_word);
		//printf("[*] current word converted to uint64_t: %" PRIu64 "\n", str2uint64(current_word));
		data[i] = str2uint64(current_word);
		i++;
	}

	fclose(dictionary);
	free(current_word);
	return data;
}

__constant__ uint64_t deviceConstantSalt;
__constant__ uint64_t deviceConstantencrypted_password;

__global__ void kernel(uint64_t *fullDictionary, uint64_t *found) {
	int wordIndex = blockIdx.x * blockDim.x + threadIdx.x;
	if (wordIndex < DICTIONARY_SIZE) {
		uint64_t current_password = fullDictionary[wordIndex];
		uint64_t encrypted = full_des_encode_block(current_password, deviceConstantSalt);
		//printf("[cuda] index: %d, current_password: %" PRIu64 ", salt: %" PRIu64 ", deviceConstantencrypted_password: %" PRIu64 "\n", wordIndex, current_password, deviceConstantSalt, deviceConstantencrypted_password);
		if (encrypted == deviceConstantencrypted_password) {
			*found = current_password;
			return;
		}
	}
}

void execute(int blockSize) {

	const char *password = "6Melissa"; // target password
	const char *salt = "PC";

	printf("[*] Target password: %s\n", password);
	printf("[*] Salt: %s\n", salt);

	uint64_t uint_salt = str2uint64(salt);
	uint64_t uint_password = str2uint64(password);

	printf("[*] Target password as uint64_t: ");
	bits_print_grouped(uint_password, 8, 64);

	// encrypt password with DES
	printf("[*] Encrypting password...\n");
	uint64_t encrypted_password = full_des_encode_block(uint_password, uint_salt);

	uint64_t *host_dictionary;
	uint64_t *device_dictionary;

	uint64_t *password_found;
	uint64_t *device_password_found;

	// Allocate host memory
	printf("[*] Allocating host memory...\n");
	host_dictionary = populateDictionary();
	password_found = (uint64_t *)malloc(sizeof(uint64_t));

	// Allocate and set device memory
	printf("[*] Allocating device memory...\n");
	CUDA_CHECK_RETURN(cudaMalloc((void **)&device_dictionary, sizeof(uint64_t)*DICTIONARY_SIZE));
	CUDA_CHECK_RETURN(cudaMalloc((void **)&device_password_found, sizeof(uint64_t)));
	CUDA_CHECK_RETURN(cudaMemset(device_password_found, 0, sizeof(uint64_t)));

	// Copy from host to device memory
	printf("[*] Copying memory host->device...\n");
	CUDA_CHECK_RETURN(cudaMemcpy(device_dictionary, host_dictionary, sizeof(uint64_t)*DICTIONARY_SIZE, cudaMemcpyHostToDevice));
	CUDA_CHECK_RETURN(cudaMemcpyToSymbol(deviceConstantSalt, &uint_salt, sizeof(uint64_t)));
	CUDA_CHECK_RETURN(cudaMemcpyToSymbol(deviceConstantencrypted_password, &encrypted_password, sizeof(uint64_t)));

	// Start clock
	clock_t start = clock();

	// Organize grid
	dim3 blockDim(blockSize);
	dim3 gridDim(DICTIONARY_SIZE/blockDim.x + 1);

	// Execute kernel
	printf("[*] Launching kernel...\n");
	kernel<<<gridDim, blockDim>>>(device_dictionary, device_password_found);
	cudaDeviceSynchronize();

	// Copy results from device memory to host
	printf("[*] Copying memory device->host...\n");
	CUDA_CHECK_RETURN(cudaMemcpy(password_found, device_password_found, sizeof(uint64_t), cudaMemcpyDeviceToHost));

	// Check if password was decrypted
	if (*password_found) {

		// End clock
		clock_t end = clock();

		printf("[✓] Successfully decrypted password: ");
		bits_print_grouped(*password_found, 8, 64);

		printf("[i] GPU time: %.5f seconds\n", (float)(end - start)/CLOCKS_PER_SEC);
	} else {
		printf("[*] Password not found in dictionary!\n");
	}

	printf("[*] Cleaning up...");

	// Free GPU memory
	CUDA_CHECK_RETURN(cudaFree(device_dictionary));
	CUDA_CHECK_RETURN(cudaFree(device_password_found));

	// Free host memory
	free(host_dictionary);
	free(password_found);
}

int main(void) {
	int blocks[7];
	for (int i=3, j=0; i < 10; i++, j++) {
		blocks[j] = pow(2,i);
	}
	for (int i=0; i<sizeof(blocks)/sizeof(blocks[0]); i++) {
		printf("\n\n===> Executing with %d blocks and %d threads per block\n\n", blocks[i], blocks[i]);
		execute(blocks[i]);
	}
}
