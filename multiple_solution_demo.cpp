#include <iostream>
#include <cstring>

using namespace std;

struct FrameReferenceInfo {
    FrameReferenceInfo(uint32_t p) {count=p;};
    uint32_t count;
};

struct FrameStore {
    uint8_t* store_cx;
    uint8_t* store_dx;
    uint8_t* store_bx;
    uint8_t* store_sp;
    uint8_t* store_bp;
    uint8_t* store_si;
    uint8_t* store_di;
    uint8_t* store_8;
    uint8_t* store_9;
    uint8_t* store_12;
    uint8_t* store_13;
    uint8_t* store_14;
    uint8_t* store_15;
    FrameReferenceInfo* fri=nullptr;
    uint32_t stack_storage_index;
    uint32_t size;
    uint32_t clause_index;
};

uint8_t* stack_storage=new uint8_t[1000];
FrameStore frames[10];
uint32_t frame_count=0;
uint8_t* base_sp=0;
uint32_t global_stack_storage_index=0;

FrameStore* __attribute__ ((noinline)) process_stack_state(FrameReferenceInfo* fri) {
    if(fri) {
        // first time through - store the data
        FrameStore& fs=frames[frame_count++];
        fs.fri=fri;
        uint8_t* store_cx;
        uint8_t* store_dx;
        uint8_t* store_bx;
        uint8_t* store_sp;
        uint8_t* store_bp;
        uint8_t* store_si;
        uint8_t* store_di;
        uint8_t* store_8 ;
        uint8_t* store_9 ;
        uint8_t* store_12;
        uint8_t* store_13;
        uint8_t* store_14;
        uint8_t* store_15;
        asm("mov %%rcx, %0;" :"=r"(fs.store_cx));
        asm("mov %%rdx, %0;" :"=r"(fs.store_dx));
        asm("mov %%rbx, %0;" :"=r"(fs.store_bx));
        asm("mov %%rsp, %0;" :"=r"(fs.store_sp));
        asm("mov %%rbp, %0;" :"=r"(fs.store_bp));
        asm("mov %%rsi, %0;" :"=r"(fs.store_si));
        asm("mov %%rdi, %0;" :"=r"(fs.store_di));
        asm("mov %%r8 , %0;" :"=r"(fs.store_8 ));
        asm("mov %%r9 , %0;" :"=r"(fs.store_9 ));
        asm("mov %%r12, %0;" :"=r"(fs.store_12));
        asm("mov %%r13, %0;" :"=r"(fs.store_13));
        asm("mov %%r14, %0;" :"=r"(fs.store_14));
        asm("mov %%r15, %0;" :"=r"(fs.store_15));
        uint8_t* this_fa=fs.store_sp;
        fs.size=base_sp-this_fa;
        fs.stack_storage_index=global_stack_storage_index;
        fs.clause_index=0;
        memcpy(&stack_storage[global_stack_storage_index],base_sp-fs.size,fs.size);
        global_stack_storage_index+=fs.size;
        return &fs;
    }
    // Subsequent pass - restore the data
    FrameStore& fs=frames[frame_count-1];
    fs.clause_index++;
    // Can't make a call here as messing up the stack, and can't use any outside code until complete
    uint64_t* dst=(uint64_t*)(&base_sp[-(int64_t)fs.size]);
    uint64_t* src=(uint64_t*)(&stack_storage[global_stack_storage_index-fs.size]);
    for(uint32_t i=0;i<fs.size>>3;i++) {
        dst[i]=src[i];
    }
    if(fs.clause_index+1>=fs.fri->count) {
        // last time through
        frame_count--;
        global_stack_storage_index-=fs.size;
    }
    asm("mov %0, %%rcx;" ::"r"(fs.store_cx));
    asm("mov %0, %%rdx;" ::"r"(fs.store_dx));
    asm("mov %0, %%rbx;" ::"r"(fs.store_bx));
    asm("mov %0, %%rsp;" ::"r"(fs.store_sp));
    asm("mov %0, %%rbp;" ::"r"(fs.store_bp));
    asm("mov %0, %%rsi;" ::"r"(fs.store_si));
    asm("mov %0, %%rdi;" ::"r"(fs.store_di));
    asm("mov %0, %%r8 ;" ::"r"(fs.store_8 ));
    asm("mov %0, %%r9 ;" ::"r"(fs.store_9 ));
    asm("mov %0, %%r12;" ::"r"(fs.store_12));
    asm("mov %0, %%r13;" ::"r"(fs.store_13));
    asm("mov %0, %%r14;" ::"r"(fs.store_14));
    asm("mov %0, %%r15;" ::"r"(fs.store_15));
    return &fs;
}

static FrameReferenceInfo test1_fri(2);
static FrameReferenceInfo test2_fri(2);

void test2(int x) {
    FrameStore* fs=process_stack_state(&test2_fri);
    switch(fs->clause_index) {
        case 0: {
            cout << x << endl;
        } break;
        case 1: {
            cout << x+1 << endl;
        } break;
    }
}

void test1() {
    FrameStore* fs=process_stack_state(&test1_fri);
    switch(fs->clause_index) {
        case 0: {
            test2(0);
        } break;
        case 1: {
            test2(2);
        } break;
    }
}

int main() {
    base_sp=(uint8_t*)__builtin_frame_address(0);
    test1();
    while(frame_count>0) {
        process_stack_state(nullptr);
    }
    return 0;
}
