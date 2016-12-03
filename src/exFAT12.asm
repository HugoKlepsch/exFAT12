
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                                 ;
; exFAT12.asm                                                                       ;
;                                                                                 ;
; Copyright (c) 2016, Mike Gonta                                                  ;         
; mikegonta.com                                                                   ;
;                                                                                 ;
; This software is provided 'as-is', without any express or implied warranty. In  ;
; no event will the authors be held liable for any damages arising from the use   ;
; of this software.                                                               ;
;                                                                                 ;
; Permission is granted to anyone to use this software for any purpose, including ;
; commercial applications, and to alter it and redistribute it freely, subject to ;
; the following restrictions:                                                     ;
;                                                                                 ;
; 1. The origin of this software must not be misrepresented; you must not claim   ;
;    that you wrote the original software. If you use this software in a product, ;
;    an acknowledgement in the product documentation would be appreciated but is  ;
;    not required.                                                                ;
;                                                                                 ;
; 2. Altered source versions must be plainly marked as such, and must not be      ;
;    misrepresented as being the original software.                               ;
;                                                                                 ;
; 3. This notice may not be removed or altered from any source distribution.      ;
;                                                                                 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

include "date_time.inc"
FILE equ "kernel.bin"

org 0x7C00
boot_sector:
  jmp boot
  nop
file_system_name: db "EXFAT   "
  times 53 db 0
partition_offset: dq 0
volume_length: dq 2880 ; 1.44MB image
fat_offset: dd 24
fat_length: dd 23
cluster_heap_offset: dd 47
cluster_count: dd 2833
root_directory_cluster_number: dd 15
volume_serial_number: db MONTHS + SECONDS, DAYS + HUNDREDTHS
                      db (YEARS / 100) + HOURS, (YEARS MOD 100) + MINUTES
file_system_revision: dw 0x100
volume_flags: dw 0
bytes_per_sector_shift: db 9
sectors_per_cluster_shift: db 0
number_of_fats: db 1
drive_select: db 0x80
percent_in_use: db 0
  times 7 db 0

boot:
  xor ax, ax
  mov ds, ax
  mov es, ax
  mov ss, ax
  mov sp, 0x7C00
  mov [drive_select], dl
  
  mov si, disk_address_packet
  mov BYTE [si], 16 ; packet size
  mov BYTE [si + 2], 15 ; pre-allocated root directory clusters
  mov WORD [si + 4], root_directory
  mov ax, [root_directory_cluster_number]
  add ax, [cluster_heap_offset]
  dec ax
  dec ax
  mov [si + 8], ax ; LBA
  mov ah, 0x42
  int 0x13
  jc error
  call checksum
  mov cx, 16 * 15
  mov si, root_directory - 32
.1:
  lea si, [si + 32]
  cmp BYTE [si], 0xC0 ; stream extension directory entry
  jne .3
  cmp bx, [si + 4] ; file name checksum
  jne .3
  mov ax, dx ; FILE name length
  xchg cx, ax ; save cx and restore length
  cmp cl, [si + 3] ; file name length
  jne .2
  lea si, [si + 32] ; file name directory entry
  call compare
  je file_found
.2:
  xchg cx, ax ; restore cx loop count
.3:
  loop .1
  mov si, cant_find
  call print
  mov si, press_any_key

exit:
  call print
  xor ah, ah
  int 0x16
  int 0x19

error:
  mov si, drive_error
  jmp exit

file_found:
  mov ax, [si - 24] ; valid data length
  mov bx, [si - 12] ; first cluster
  add bx, [cluster_heap_offset]
  dec bx
  dec bx
  add ax, 511
  shr ax, 9
  mov si, disk_address_packet
  mov [si + 2], ax ; count
  mov DWORD [si + 4], 0x10000000 ; address
  mov [si + 8], bx ; lba
  mov ah, 0x42
  mov dl, [drive_select]
  int 0x13
  jc error
  jmp 0x1000:0000

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

checksum:
  xor ax, ax
  xor bx, bx
  xor dx, dx
  mov si, file_name
.1:
  lodsb
  test al, al
  je .2
  call toupper
  ror bx, 1
  add bx, ax
  ror bx, 1
  inc dx
  jmp .1
.2:
  ret

compare:
  push ax
  push si
  inc si
  inc si
  mov di, file_name
.1:
  lodsw
  call toupper
  mov ah, al
  mov al, [di]
  inc di
  call toupper
  cmp ah, al
  loope .1
  pop si
  pop ax
  ret

toupper:
  cmp al, 'a'
  jb .1
  cmp al, 'z'
  ja .1
  sub al, 0x20
.1:
  ret

cant_find:
  db "Can't find the file "
file_name: db FILE, 0 ; 8.3 format
  times 13 - ($ - file_name) db 0
drive_error:
  db "Drive error"
press_any_key:
  db "!", 0x0D, 0x0A, "Press any key to continue...", 0x0D, 0x0A, 0

  times 446 - ($ - boot_sector) db 0

self_referencing_mbr:
  db 0 ; status
  db 0, 0, 0 ; H, S, C of first block - not required
  db 7 ; partition type exFAT
  db 0, 0, 0 ; H, S, C of last block - not required
  dd 0 ; LBA of first sector
  dd 2880 ; number of blocks

disk_address_packet:
  db 0, 0
  db 0, 0 ; number of sectors
  dw 0, 0 ; address
  dw 0, 0, 0, 0 ; lba

  times 64 - ($ - self_referencing_mbr) db 0

  dw 0xAA55

root_directory:
extended_boot_sectors:
repeat 8
  times 510 db 0
  dw 0xAA55
end repeat

  times 512 * 2 db 0

boot_sector_checksum = 0
index = boot_sector
repeat $ - boot_sector
  if index <> volume_flags & index <> volume_flags + 1 & index <> percent_in_use
    load x BYTE from index
    boot_sector_checksum = (((boot_sector_checksum SHL 31) OR (boot_sector_checksum SHR 1))+ x) AND 0xFFFFFFFF
  end if
  index = index + 1
end repeat

boot_checksum:
  times 512 / 4 dd boot_sector_checksum

backup_boot_region:
times 512 * 12 db 0
index = 0
repeat 512 * 12 / 4
  load x DWORD from boot_sector + index
  store DWORD x at backup_boot_region + index
  index = index + 4
end repeat

file "exFAT12.img" : 512 * 24, 512 * 51

;  times (2880 * 512) - ($ - $$) db 0

