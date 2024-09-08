# BSD 3-Clause License
#
# Copyright (c) 2024, Roy Ward
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

.globl  _ZN6Prolog29process_stack_state_load_saveEi # -- Begin function Prolog::process_stack_state_load_save(FrameStore* fs)
        .p2align 4, 0x90
        .type   _ZN6Prolog29process_stack_state_load_saveEi,@function
_ZN6Prolog29process_stack_state_load_saveEi: # @Prolog::process_stack_state_load_save(FrameStore* fs)
        test   %esi,%esi
        jne     restore
        mov    0x8(%rdi),%eax # frame top
        mov    0xC(%rdi),%edx # frame size
        mul    %edx
        mov    0x0(%rdi),%rdx
        lea    0x0(%rdx,%rax),%rsi

        mov    %rbx,(%rsi)
        mov    %rsp,0x08(%rsi)
        mov    %rbp,0x10(%rsi)
        mov    %r12,0x18(%rsi)
        mov    %r13,0x20(%rsi)
        mov    %r14,0x28(%rsi)
        mov    %r15,0x30(%rsi)
        mov    %rsi,%rbx # fs
        call    _ZN6Prolog28process_stack_state_save_auxEP10FrameStore
        mov    %rbx,%rax
        mov    (%rbx),%rbx # rbx is callee saved
        ret
restore:
        mov    %rdi,%rbx # save 'this'. going to need it later
        call   _ZN6Prolog28process_stack_state_load_auxEj
        # rax - scratch,store
        # rcx - counter for scratch_buf entries
        # rdx - store
        # rbx - this
        # rpb - scratch buf base
        # rsi - live
        # rdi - memory copy counter
        # r8  - memory copy limit
        # r9  - frame size
        mov    %eax,%ecx #guarantee at least one frame to copy, so don't need to check for <0
        #mov    $0,%ecx
        mov    0xC(%rbx),%r9d # frame size
        mov    0x10(%rbx),%rbp # scratch buf base
outer_loop:
        mov    0x0(%rbp,%rcx,4),%eax # current frame
        mul    %r9d
        mov    0x0(%rbx),%rdx
        lea    0x0(%rdx,%rax),%rax
        mov    0x48(%rax),%r8 #fs->size
        test   %r8,%r8
        je     copy_to_stack_noloop
        mov    0x38(%rax),%rdx # fs->store
        mov    0x40(%rax),%rsi # fs->live
        xor    %edi,%edi
        .p2align 4, 0x90
copy_to_stack_loop:
#ifdef USE_AVX
        vmovaps (%rdx,%rdi),%ymm0
        vmovaps %ymm0,(%rsi,%rdi)
        add    $0x20,%edi
#else
        movaps (%rdx,%rdi),%xmm0
        movaps %xmm0,(%rsi,%rdi)
        add    $0x10,%edi
#endif
        cmp    %edi,%r8d
        jne    copy_to_stack_loop
copy_to_stack_noloop:
        sub    $1,%ecx
        jge    outer_loop
        mov    0x30(%rax),%r15
        mov    0x28(%rax),%r14
        mov    0x20(%rax),%r13
        mov    0x18(%rax),%r12
        mov    0x10(%rax),%rbp
        mov    0x08(%rax),%rsp
        mov    (%rax),%rbx
        ret    
