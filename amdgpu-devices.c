// Copyright (c) 2016 Wladimir J. van der Laan
// Distributed under the MIT software license.
// Based on an example from the OpenCL cookbook.

#include <stdio.h>
#include <stdlib.h>
#ifdef __APPLE__
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif

struct platform_data_item {
    int id;
    char *name;
};

struct platform_data_item platform_data_items[] = {
    { CL_PLATFORM_PROFILE, "Profile"},
    { CL_PLATFORM_VERSION, "Version"},
    { CL_PLATFORM_NAME,    "Name"},
    { CL_PLATFORM_VENDOR,  "Vendor"},
    { CL_PLATFORM_EXTENSIONS, "Extensions"},
};

#define ARRAYLEN(array)     (sizeof(array)/sizeof((array)[0]))

int main() {
 
    int i, j;
    char* value;
    size_t valueSize;
    cl_uint platformCount = 0;
    cl_platform_id* platforms;
    cl_uint deviceCount;
    cl_device_id* devices;
    cl_uint maxComputeUnits;
 
    // get all platforms
    if (clGetPlatformIDs(0, NULL, &platformCount) != CL_SUCCESS) {
        printf("Unable to get platform IDs\n");
        exit(1);
    }
    platforms = (cl_platform_id*) malloc(sizeof(cl_platform_id) * platformCount);
    if (clGetPlatformIDs(platformCount, platforms, NULL) != CL_SUCCESS) {
        printf("Unable to get platform IDs\n");
        exit(1);
    }
 
    for (i = 0; i < platformCount; i++) {
        printf("%i. Platform\n", i+1);

        char data[1024];
        size_t retsize;
        for (int j=0; j<ARRAYLEN(platform_data_items); ++j) {
            if (clGetPlatformInfo(platforms[i], platform_data_items[j].id, sizeof(data), data, &retsize) != CL_SUCCESS || retsize == sizeof(data)) {
                printf("Unable to get platform %s\n", platform_data_items[j].name);
                continue;
            }
            printf("  %s: %s\n", platform_data_items[j].name, data);
        }
 
        // get all devices
        if (clGetDeviceIDs(platforms[i], CL_DEVICE_TYPE_ALL, 0, NULL, &deviceCount) != CL_SUCCESS) {
            printf("Unable to get device IDs for platform %p\n", platforms[i]);
            continue;
        }
        devices = (cl_device_id*) malloc(sizeof(cl_device_id) * deviceCount);
        if (clGetDeviceIDs(platforms[i], CL_DEVICE_TYPE_ALL, deviceCount, devices, NULL) != CL_SUCCESS) {
            printf("Unable to get device IDs for platform %p\n", platforms[i]);
            continue;
        }
 
        // for each device print critical attributes
        for (j = 0; j < deviceCount; j++) {
 
            // print device name
            clGetDeviceInfo(devices[j], CL_DEVICE_NAME, 0, NULL, &valueSize);
            value = (char*) malloc(valueSize);
            clGetDeviceInfo(devices[j], CL_DEVICE_NAME, valueSize, value, NULL);
            printf("%d. Device: %s\n", j+1, value);
            free(value);
 
            // print hardware device version
            clGetDeviceInfo(devices[j], CL_DEVICE_VERSION, 0, NULL, &valueSize);
            value = (char*) malloc(valueSize);
            clGetDeviceInfo(devices[j], CL_DEVICE_VERSION, valueSize, value, NULL);
            printf(" %d.%d Hardware version: %s\n", j+1, 1, value);
            free(value);
 
            // print software driver version
            clGetDeviceInfo(devices[j], CL_DRIVER_VERSION, 0, NULL, &valueSize);
            value = (char*) malloc(valueSize);
            clGetDeviceInfo(devices[j], CL_DRIVER_VERSION, valueSize, value, NULL);
            printf(" %d.%d Software version: %s\n", j+1, 2, value);
            free(value);
 
            // print c version supported by compiler for device
            clGetDeviceInfo(devices[j], CL_DEVICE_OPENCL_C_VERSION, 0, NULL, &valueSize);
            value = (char*) malloc(valueSize);
            clGetDeviceInfo(devices[j], CL_DEVICE_OPENCL_C_VERSION, valueSize, value, NULL);
            printf(" %d.%d OpenCL C version: %s\n", j+1, 3, value);
            free(value);
 
            // print parallel compute units
            clGetDeviceInfo(devices[j], CL_DEVICE_MAX_COMPUTE_UNITS,
                    sizeof(maxComputeUnits), &maxComputeUnits, NULL);
            printf(" %d.%d Parallel compute units: %d\n", j+1, 4, maxComputeUnits);
 
        }
 
        free(devices);
 
    }
 
    free(platforms);
    return 0;
 
}
