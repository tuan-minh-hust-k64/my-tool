reload_nginx() {
  docker exec nginx-pro /usr/sbin/nginx -s reload
}
check_container() {
  ip="$1"
  port="$2"

  if [ $port -eq '3000' ]; then
    port="3001"
  else
    port="3000"
  fi
  max_attempts=10
  attempt=1

  while [ $attempt -le $max_attempts ]; do
    if nc -z -w1 $ip $port; then
      echo "Cổng $port của địa chỉ IP $ip đã sẵn sàng."
      break
    else
      echo "Cổng $port của địa chỉ IP $ip chưa sẵn sàng. Đợi trong 1 giây..."
      sleep 1
      attempt=$((attempt + 1))
    fi
  done

  if [ $attempt -gt $max_attempts ]; then
    echo "Cổng $port của địa chỉ IP $ip không sẵn sàng sau $max_attempts lần thử."
    if [ $port -eq '3000' ]; then
      port="3001"
    else
      port="3000"
    fi
    max_attempts=10
    attempt=1

    while [ $attempt -le $max_attempts ]; do
      if nc -z -w1 $ip $port; then
        echo "Cổng $port của địa chỉ IP $ip đã sẵn sàng."
        break
      else
        echo "Cổng $port của địa chỉ IP $ip chưa sẵn sàng. Đợi trong 1 giây..."
        sleep 1
        attempt=$((attempt + 1))
      fi
    done
    if [ $attempt -gt $max_attempts ]; then
      echo "Cổng $port của địa chỉ IP $ip không sẵn sàng sau $max_attempts lần thử."
      exit 0
    fi
  fi

}
if [ "$#" -eq 0 ]; then
  echo "Truyền service vào bạn êi!!!"
  exit 0
fi

service_name=$1
zero_downtime_deploy() {  
  image_name=$(docker-compose images | grep $service_name | tail -n1 | awk '{print $2}')
  # docker pull $image_name:latest
  port_service=$(docker ps --filter name=$service_name --format "table {{.Ports}}" | tail -n1 | awk -F"/" '{print $1}')
  old_container_id=$(docker ps -f name=$service_name -q | tail -n1)
  docker-compose up -d --no-deps --scale $service_name=2 --no-recreate $service_name

  new_container_id=$(docker ps -f name=$service_name -q | head -n1)
  new_container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $new_container_id)
  
  check_container $new_container_ip $port_service
  echo "waiting ..."
  reload_nginx  
  sleep 5
  echo "oo"
  echo "start deploy"
  docker stop $old_container_id
  docker rm $old_container_id
  docker-compose up -d --no-deps --scale $service_name=1 --no-recreate $service_name
  reload_nginx  

  docker image prune -f
  echo "finish"
}
zero_downtime_deploy