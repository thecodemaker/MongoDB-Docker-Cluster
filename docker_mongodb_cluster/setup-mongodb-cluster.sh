#!/bin/bash

ip_rs1_srv1=""
ip_rs1_srv2=""
ip_rs1_srv3=""
default_port="27017"

#clean
sudo docker ps -a -q | sudo xargs docker stop | sudo xargs docker rm

#create docker images
sudo docker build -t dev0/mongodb mongod
sudo docker build -t dev0/mongos mongos

#create a replica set
for i in {1..3}
do
    data_dir="/data/docker-persisted-data/mongo_srv${i}"
    mkdir -p ${data_dir}

    container_name="rs1_srv${i}"

    sudo docker run                  \
        --name ${container_name}     \
        -P -d dev0/mongodb           \
        -v ${data_dir}:/data/mongodb \
            --noprealloc             \
            --smallfiles             \
            --replSet rs1            \
            --dbpath /data/mongodb   \
            --profile=0              \
            --slowms=-1

    IP=$(sudo docker inspect ${container_name} | grep IPAddress | cut -d '"' -f 4)

    echo $(sudo docker inspect ${container_name})

#    case ${i} in
#        1) ip_rs1_srv1=$IP
#           ;;
#        2) ip_rs1_srv2=$IP
#           ;;
#        3) ip_rs1_srv3=$IP
#           ;;
#    esac
done

#sleep 10

#mongo --port 49153 << 'EOF'
#    config = { _id: "rs1", members:[
#              { _id : 0, host : "${ip_rs1_srv1}:${default_port}" },
#              { _id : 1, host : "${ip_rs1_srv2}:${default_port}" },
#              { _id : 2, host : "${ip_rs1_srv3}:${default_port}" }]
#             };
#    rs.initiate(config)
#EOF
#
#sleep 10
#
#mongo --port 49153 << 'EOF'
#    rs.status()
#EOF




