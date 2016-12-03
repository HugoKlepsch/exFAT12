  push cs
  pop ds
  jmp last
  times 512 * 126 db 0

last:
  mov si, hello
  jmp exit

hello: db 0x0D, 0x0A, "Hello exFAT12 World!", 0x0D, 0x0A, 0
print:
  cld
.1:
  mov ah, 0x0E
  xor bh, bh
  lodsb
  test al, al
  je .2
  int 0x10
  jmp .1
.2:
  ret

exit:
  call print
  xor ah, ah
  int 0x16
  int 0x19

