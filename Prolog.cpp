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

void Prolog::pop_frame_stack(FrameStore* fs) {
    if(frame_count-1==fs->frame_index) {
        frame_count--;
    }
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

void __attribute__ ((noinline)) Prolog::process_stack_state_save_aux(FrameStore* fs) {
    fs->stack_bottom=fs->store_sp;
    uint64_t size8=(base_sp-fs->stack_bottom)>>3;
    uint64_t* dst=(uint64_t*)(&stack_storage[STACK_SIZES+fs->stack_bottom-base_sp]);
    uint64_t* src=(uint64_t*)fs->stack_bottom;
    for(uint32_t i=0;i<size8;i++) {
        dst[i]=src[i];
    }
    fs->frame_top_unwind_stack_decouple_mark=top_unwind_stack_decouple_mark;
}

FrameStore* __attribute__ ((noinline)) Prolog::process_stack_state_load_aux() {
    // Subsequent pass - restore the data
    FrameStore* fs_low=&frames[frame_count-1];
    top_unwind_stack_decouple_mark=fs_low->frame_top_unwind_stack_decouple_mark;
    uint32_t bottom=unwind_stack_decouple_mark[top_unwind_stack_decouple_mark-1];
    for(uint32_t i=bottom;i<top_unwind_stack_decouple;i++) {
        variables[unwind_stack_decouple[i]]=0;
    }
    fs_low->dst=(uint64_t*)(fs_low->stack_bottom);
    fs_low->src=(uint64_t*)(&stack_storage[STACK_SIZES+fs_low->stack_bottom-base_sp]);
    fs_low->size=(base_sp-fs_low->stack_bottom)>>3;
    return fs_low;
}

void Prolog::unwind_stack_mark() {
    unwind_stack_decouple_mark[top_unwind_stack_decouple_mark++]=top_unwind_stack_decouple;
}

void Prolog::unwind_stack_revert_to_mark() {
    uint32_t bottom=unwind_stack_decouple_mark[top_unwind_stack_decouple_mark-1];
    for(uint32_t i=bottom;i<top_unwind_stack_decouple;i++) {
        variables[unwind_stack_decouple[i]]=0;
    }
}

int main() {
    Prolog p;
    p.__do_start();
    return 0;
}
