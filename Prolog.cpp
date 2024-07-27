/*
Data structures:
uint32_t variables[]
uint64_t list_values[]
uint32_t unwind_stack_decouple[]
uint32_t unwind_stack_delete[]
Tags in low bits - tags are not for that type, but for the type that it is pointing to:
......000 vref (chase these ones)
......001 ununified vref
......010 list
......110 eol
......100 integer
*/
// pre: tag2:001, &val2=0
// pre: tag1:100, val1=value;
#include "Prolog.h"
#include <sstream>
#include <cstring>

// bool Prolog::unify(uint32_t val1, uint32_t voffset1, uint32_t val2, uint32_t voffset2) {
//     // First do any pointer chasing. There may be benefits to checking variable matching first
//     pointer_chase(val1,voffset1);
//     pointer_chase(val2,voffset2);
//     uint8_t tag2=val2&TAG_MASK;
//     uint8_t tag1=val1&TAG_MASK;
//     if(tag2==TAG_VREF_UNUNIFIED) {
//         variables[(val2>>TAG_WIDTH)+voffset2]=val1;
//         return true;
//     }
//     if(tag1==TAG_VREF_UNUNIFIED) {
//         variables[(val1>>TAG_WIDTH)+voffset1]=val2;
//         return true;
//     }
//     return false;
// }

bool Prolog::unify(uint32_t val1, uint32_t val2) {
    // First do any pointer chasing. There may be benefits to checking variable matching first
    uint8_t tag1;
    pointer_chase(tag1,val1);
    uint8_t tag2;
    pointer_chase(tag2,val2);
    if(tag2==TAG_VREF) {
        variables[(val2>>TAG_WIDTH)]=val1;
        unwind_stack_decouple[top_unwind_stack_decouple++]=val2>>TAG_WIDTH;
        return true;
    }
    if(tag1==TAG_VREF) {
        variables[(val1>>TAG_WIDTH)]=val2;
        unwind_stack_decouple[top_unwind_stack_decouple++]=(val1>>TAG_WIDTH);
        return true;
    }
    if(tag1!=tag2) {
        return false;
    }
    switch(tag1) {
        case TAG_LIST: {
            List& l1=list_values[val1>>TAG_WIDTH];
            List& l2=list_values[val2>>TAG_WIDTH];
            return unify(l1.head,l2.head) && unify(l1.tail,l2.tail);
        } break;
        case TAG_EOL: {
            return true;
        } break;
        case TAG_INTEGER: {
            return val1==val2;
        } break;
        default: return false;
    }
}

// bool Prolog::match_eol(uint32_t val) {
//     pointer_chase(val);
//     uint8_t tag=val&TAG_MASK;
//     if(tag==TAG_EOL) {
//         return true;
//     }
//     if(tag==TAG_VREF_UNUNIFIED) {
//         variables[val>>TAG_WIDTH]=TAG_EOL;
//         unwind_stack_decouple[top_unwind_stack_decouple++]=val>>TAG_WIDTH;
//         return true;
//     }
//     return false;
// }
// 
// bool Prolog::match_int(uint32_t i,uint32_t val) {
//     pointer_chase(val);
//     uint8_t tag=val&TAG_MASK;
//     if(tag==TAG_INTEGER) {
//         return (val>>TAG_WIDTH)==i;
//     }
//     if(tag==TAG_VREF_UNUNIFIED) {
//         variables[val>>TAG_WIDTH]=(i<<TAG_WIDTH)+TAG_INTEGER;
//         unwind_stack_decouple[top_unwind_stack_decouple++]=val>>TAG_WIDTH;
//         return true;
//     }
//     return false;
// }
// 
// bool Prolog::match_var(uint32_t v,uint32_t val, uint32_t voffset) {
//     pointer_chase(val);
//     variables[(v>>TAG_WIDTH)+voffset]=val;
//     unwind_stack_decouple[top_unwind_stack_decouple++]=v>>TAG_WIDTH;
//     return true;
// }
 
void Prolog::delete_list_cell(uint32_t cell) {
    list_values[cell].head=freelist_list;
    freelist_list=cell;
}

uint32_t Prolog::plcreate_eol() {
    return TAG_EOL;
}

uint32_t Prolog::plcreate_int(uint32_t i) {
    return (i<<TAG_WIDTH)+TAG_INTEGER;
}

uint32_t Prolog::plcreate_var(uint32_t i) {
    if(top_variables<i+1) {
        top_variables=i+1;
    }
    return (i<<TAG_WIDTH)+TAG_VREF;
}

uint32_t Prolog::plcreate_list(uint32_t h, uint32_t t) {
    uint32_t l=get_list_cell();
    list_values[l].head=h;
    list_values[l].tail=t;
    return (l<<TAG_WIDTH)+TAG_LIST;
}

std::string Prolog::pldisplay(uint32_t i) {
    std::stringstream ss;
    pldisplay_aux(ss,' ',false,i);
    return ss.str();
}

void Prolog::pldisplay_aux(std::stringstream& ss, char ch, bool in_list, uint32_t i) {
    uint8_t tag;
    pointer_chase(tag,i);
    if(tag==TAG_EOL && in_list) {
        return;
    }
    uint32_t v=i>>TAG_WIDTH;
    if(ch!=' ') {
        ss << ch;
    }
    switch(tag) {
        case TAG_VREF: {
            ss << '_' << v;
        } break;
        case TAG_LIST: {
            if(!in_list) {
                ss << '[';
            }
            List& l=list_values[v];
            pldisplay_aux(ss,' ',false,l.head);
            pldisplay_aux(ss,',',true,l.tail);
            if(!in_list) {
                ss << ']';
            }
        } break;
        case TAG_EOL: {
            if(ch==' ') {
                ss << '[';
            }
            ss << ']';
        } break;
        case TAG_INTEGER: {
            ss << v;
        } break;
        default: {
            ss << "<error>";
        }
    }
}

FrameStore* __attribute__ ((noinline)) Prolog::process_stack_state(FrameReferenceInfo* fri) {
    if(fri) {
        // first time through - store the data
        FrameStore& fs=frames[frame_count++];
        fs.fri=fri;
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
    for(uint32_t i=0;i<fs.size>>TAG_WIDTH;i++) {
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

void Prolog::unwind_stack_mark() {
    unwind_stack_decouple_mark[top_unwind_stack_decouple_mark++]=top_unwind_stack_decouple;
}

void Prolog::unwind_stack_revert_to_mark() {
    uint32_t bottom=unwind_stack_decouple_mark[--top_unwind_stack_decouple_mark];
    for(uint32_t i=bottom;i<top_unwind_stack_decouple;i++) {
        variables[unwind_stack_decouple[i]]=0;
    }
}

void Prolog::pop_frame_stack() {
    FrameStore& fs=frames[frame_count-1];
    frame_count--;
    global_stack_storage_index-=fs.size;
}

int main() {
    Prolog p;
    p.__do_start();
    return 0;
}
