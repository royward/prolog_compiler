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

.globl  process_stack_state_load_save # -- Begin function Prolog::process_stack_state_load_save(FrameStore* fs)
        .p2align 4, 0x90
        .type   process_stack_state_load_save,@function
process_stack_state_load_save: # @Prolog::process_stack_state_load_save(FrameStore* fs)
        test   %esi,%esi
        jne     restore
#save
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
        sub    $0x8,%rsp
        call   process_stack_state_save_aux
        add    $0x8,%rsp
        mov    %rbx,%rax
        mov    (%rbx),%rbx # rbx is callee saved
        ret
restore:
        mov    0x0(%rdi),%rsi
        mov    0x8(%rdi),%eax # frame top
        mov    0xC(%rdi),%r9d # frame size
        mul    %r9d
        lea    0x0(%rsi,%rax),%rax
        mov    0x8(%rax),%rsp
        mov    %rax,%rbx # save the FrameStore reference. going to need it later
        sub    $0x78,%rsp
        call   process_stack_state_load_aux
        add    $0x78,%rsp
        mov    0x30(%rbx),%r15
        mov    0x28(%rbx),%r14
        mov    0x20(%rbx),%r13
        mov    0x18(%rbx),%r12
        mov    0x10(%rbx),%rbp
        mov    0x08(%rbx),%rsp
        mov    %rbx,%rax
        mov    (%rbx),%rbx
        ret
