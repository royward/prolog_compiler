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

bool Prolog::unify(uint32_t val1, uint32_t voffset1, uint32_t val2, uint32_t voffset2) {
    // First do any pointer chasing. There may be benefits to checking variable matching first
    pointer_chase(val1,voffset1);
    pointer_chase(val2,voffset2);
    uint8_t tag2=val2&TAG_MASK;
    uint8_t tag1=val1&TAG_MASK;
    if(tag2==TAG_VREF_UNUNIFIED) {
        variables[(voffset2>>3)+voffset2]=voffset1;
        return true;
    }
    if(tag1==TAG_VREF_UNUNIFIED) {
        variables[(voffset1>>3)+voffset1]=voffset2;
        return true;
    }
    return false;
}

uint32_t Prolog::get_list_cell() {
    if(freelist_list==0) {
        return top_list_values++;
    }
    uint32_t ret=freelist_list;
    freelist_list=list_values[freelist_list].head;
    return ret;
}

void Prolog::delete_list_cell(uint32_t cell) {
    list_values[cell].head=freelist_list;
    freelist_list=cell;
}

uint32_t Prolog::plcreate_eol() {
    return TAG_EOL;
}

uint32_t Prolog::plcreate_int(uint32_t i) {
    return (i<<3)+TAG_INTEGER;
}

uint32_t Prolog::plcreate_var(uint32_t i) {
    if(top_variables<i+1) {
        top_variables=i+1;
    }
    return (i<<3)+TAG_VREF_UNUNIFIED;
}

uint32_t Prolog::plcreate_list(uint32_t h, uint32_t t) {
    uint32_t l=get_list_cell();
    list_values[l].head=h;
    list_values[l].tail=t;
    return (l<<3)+TAG_LIST;
}

std::string Prolog::pldisplay(uint32_t i, uint32_t offset) {
    std::stringstream ss;
    pldisplay_aux(ss,' ',false,i,offset);
    return ss.str();
}

void Prolog::pldisplay_aux(std::stringstream& ss, char ch, bool in_list, uint32_t i, uint32_t offset) {
    pointer_chase(i,offset);
    uint8_t tag=i&TAG_MASK;
    if(tag==TAG_EOL && in_list) {
        return;
    }
    uint32_t v=i>>3;
    if(ch!=' ') {
        ss << ch;
    }
    switch(tag) {
        case TAG_VREF_UNUNIFIED: {
            ss << '_' << (v+offset);
        } break;
        case TAG_LIST: {
            if(!in_list) {
                ss << '[';
            }
            List& l=list_values[v];
            pldisplay_aux(ss,' ',false,l.head,offset);
            pldisplay_aux(ss,',',true,l.tail,offset);
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

int main() {
    Prolog p;
    p.__do_start();
    return 0;
}
