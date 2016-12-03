macro months [dayscount]{
  forward
  if DAYS > dayscount
    DAYS = DAYS - dayscount
    MONTHS = MONTHS + 1
  forward
  end if
}

TIME = %t
DAYS = TIME / (24 * 3600)
DAYS = DAYS - (DAYS + 365) / (3 * 365 + 366)
YEARS = 1970 + DAYS / 365
DAYS = DAYS MOD 365 + 1
MONTHS = 1
HOURS equ (TIME / 3600) MOD 24
MINUTES equ (TIME / 60) MOD 60
SECONDS equ TIME MOD 60 
HUNDREDTHS equ 50
CLOCK equ TIME MOD (24 * 3600)
if YEARS MOD 4 = 0
  if YEARS MOD 100 <> 0
    FEBDAYS = 29
  else if YEARS MOD 400 <> 0
    FEBDAYS = 29
  end if
else
  FEBDAYS = 28
end if
months 31, FEBDAYS, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

macro date_time{
  db YEARS / 1000 +'0', (YEARS MOD 1000) / 100 + '0'
  db (YEARS MOD 100) / 10 + '0', (YEARS MOD 10) + '0', '.'
  db MONTHS / 10 + '0', (MONTHS MOD 10) + '0', '.'
  db DAYS / 10 + '0', (DAYS MOD 10) + '0', '.'
  db CLOCK / 10000 +'0', (CLOCK MOD 10000) / 1000 + '0'
  db (CLOCK MOD 1000) / 100 + '0', ((CLOCK MOD 100) / 10) + '0'
  db (CLOCK MOD 10) + '0'
  db 0
}

      
