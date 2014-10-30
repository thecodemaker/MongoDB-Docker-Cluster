#!/bin/bash

ip_rs1_srv1=""
ip_rs1_srv2=""
ip_rs1_srv3=""
ip_cfg1=""
ip_mongos1=""
default_port="27017"

#clean
echo "********************************************Cleaning the environment"
sudo docker ps -a -q | sudo xargs docker stop | sudo xargs docker rm
sudo rm -r \
 "`pwd`/mongo-persisted-data/mongo_srv1" \
 "`pwd`/mongo-persisted-data/mongo_srv2" \
 "`pwd`/mongo-persisted-data/mongo_srv3" \
 "`pwd`/mongo-persisted-data/mongo_cfg1" \
 "`pwd`/mongo-persisted-data/mongo_mongos1"


#create docker images
echo "********************************************create docker images"
sudo docker build -t dev0/mongodb mongod
sudo docker build -t dev0/mongos mongos

#create a replica set
echo "********************************************create a replica set"
for i in {1..3}
do
    data_dir="`pwd`/mongo-persisted-data/mongo_srv${i}"
    mkdir -p ${data_dir}

    container_name="rs1_srv${i}"

    sudo docker run \
        -v ${data_dir}:/data/mongodb \
        --name ${container_name} \
        -P -d dev0/mongodb \
        --noprealloc \
        --smallfiles \
        --replSet rs1 \
        --dbpath /data/mongodb \
        --profile=0 \
        --slowms=-1

    IP=$(sudo docker inspect ${container_name} | grep IPAddress | cut -d '"' -f 4)
    echo "IP for replica server ${i} is ${IP}"
    case ${i} in
        1) ip_rs1_srv1=$IP
           ;;
        2) ip_rs1_srv2=$IP
           ;;
        3) ip_rs1_srv3=$IP
           ;;
    esac
done

sleep 5

mongo --port 49153 <<EOF
    config = { _id: "rs1", members:[
              { _id : 0, host : "${ip_rs1_srv1}:${default_port}" },
              { _id : 1, host : "${ip_rs1_srv2}:${default_port}" },
              { _id : 2, host : "${ip_rs1_srv3}:${default_port}" }]
             };
    rs.initiate(config)
EOF

sleep 20

mongo --port 49153 <<EOF
    rs.status()
EOF

#create some config servers
echo "********************************************create some config servers"

sudo docker run \
    -v "`pwd`/mongo-persisted-data/mongo_cfg1":/data/mongodb \
    --name cfg1 \
    -P -d dev0/mongodb \
    --noprealloc \
    --smallfiles \
    --configsvr \
    --dbpath /data/mongodb \
    --profile=0  \
    --slowms=-1 \
    --port 27017

ip_cfg1=$(sudo docker inspect cfg1 | grep IPAddress | cut -d '"' -f 4)
echo "IP for config server is ${ip_cfg1}"

sleep 10

##create mongod router
echo "********************************************create mongod router"

sudo docker run \
    --name mongos1 \
    -P -d dev0/mongos \
    --configdb "${ip_cfg1}:${default_port}" \
    --port 27017

ip_mongos1=$(sudo docker inspect mongos1 | grep IPAddress | cut -d '"' -f 4)
echo "IP for mongod router is ${ip_mongos1}"

sleep 10

mongo "${ip_mongos1}:${default_port}" <<EOF
    sh.addShard("rs1/${ip_rs1_srv1}:${default_port}")
    sh.status()
EOF

#sudo docker logs rs1_srv1
#sudo docker logs rs1_srv2
#sudo docker logs rs1_srv3

#sudo docker logs cfg1
#sudo docker logs mongos1