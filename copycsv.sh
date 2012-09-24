#! /bin/bash

ps aux | gawk 'match($0, "sudo -H -b -u (remote.+) logger", array) {system("cp /home/ts_users/"array[1]"/fps.csv /root/csv_files/"array[1]"_fps.csv")}'
cp /mnt/storage/profiler/usage.csv /root/csv_files
