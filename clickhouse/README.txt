http interface http://hostip:8123
for native client connect port 9000

docker run -it yandex/clickhouse-client --host ${serverip|hostip}



create table

CREATE TABLE wikistat
(
    project String,
    subproject String,
    hits UInt64,
    size UInt64
) ENGINE = Log;

insert data
docker run -i yandex/clickhouse-client  --format_csv_delimiter="|" --host ${serverhost} --query="INSERT INTO d
efault.wikistat3 FORMAT CSV" < ./data/info.csv
select result
use ui tools HouseOps https://github.com/HouseOps/HouseOps

select * from default.wikistat;



cluster

SELECT * FROM system.clusters
