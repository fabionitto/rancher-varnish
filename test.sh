#!/bin/sh
echo 0 >/dev/shm/a

back () {
   while :;do
     echo $(($(</dev/shm/a)+1)) >/dev/shm/a;
     sleep 1;
   done;
}

echo $(</dev/shm/a)
(sleep 3; back; echo 100 >/dev/shm/a) &

echo $(</dev/shm/a)
