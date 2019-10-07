// This program computes the sum of two vectors of length N
// By: Nick from CoffeeBeforeArch

#include <cassert>
#include <cstdlib>
#include <iostream>
#include <array>
#include <algorithm>
#include <iterator>

using std::begin;
using std::end;
using std::copy;
using std::generate;
using std::array;
using std::cout;
using std::endl;

// CUDA kernel for vector addition
// __global__ means this is called from the CPU, and runs on the GPU
__global__ void vectorAdd(int* a, int* b, int* c, int N) {
  // Calculate global thread ID
  int tid = (blockIdx.x * blockDim.x) + threadIdx.x;
  
  // Boundary check
  if (tid < N) {
    // Each thread adds a single element
    c[tid] = a[tid] + b[tid];
  }
}

// Check vector add result
// Templatize this to handle multiple array inputs
template <size_t SIZE>
void verify_result(array<int, SIZE>a, array<int, SIZE> b, array<int, SIZE> c) {
  for(int i = 0; i < SIZE; i++){
    assert(c[i] == a[i] + b[i]);
  }
}

int main() {
  // Vector size of 2^16 (65536 elements)
  const int N = 1 << 16;
  size_t bytes = sizeof(int) * N;

  // Arrays for holding the host-side (cpu-side) data
  array<int, N> a;
  array<int, N> b;
  array<int, N> c;

  // Initialize random numbers in each array
  generate(begin(a), end(a), [] () { return rand() % 100; });
  generate(begin(b), end(b), [] () { return rand() % 100; });

  // Allocate memory on the device
  int *d_a, *d_b, *d_c;
  cudaMalloc(&d_a, bytes);
  cudaMalloc(&d_b, bytes);
  cudaMalloc(&d_c, bytes);

  // Copy data from the host to the device (cpu -> gpu)
  cudaMemcpy(d_a, a.data(), bytes, cudaMemcpyHostToDevice);
  cudaMemcpy(d_b, b.data(), bytes, cudaMemcpyHostToDevice);

  // Threads per CTA (1024 threads per CTA)
  int NUM_THREADS = 1 << 10;

  // CTAs per Grid
  int NUM_BLOCKS = (N + NUM_THREADS - 1) / NUM_THREADS;

  // Launch the kernel on the GPU
  // Kernel calls are asynchronous (the CPU program continues execution after
  // call, but no necessarily before the kernel finishes)
  vectorAdd<<<NUM_BLOCKS, NUM_THREADS>>>(d_a, d_b, d_c, N);

  // Copy sum vector from device to host
  // cudaMemcpy is a synchronous operation, and waits for the prior kernel
  // launch to complete (both go to the default stream in this case).
  // Therefore, this cudaMemcpy acts as both a memcpy and synchronization
  // barrier.
  cudaMemcpy(c.data(), d_c, bytes, cudaMemcpyDeviceToHost);

  // Check result for errors
  verify_result<a.size()>(a, b, c);

  // Free memory on device
  cudaFree(d_a);
  cudaFree(d_b);
  cudaFree(d_c);

  printf("COMPLETED SUCCESFULLY\n");

  return 0;
}