#https://github.com/depthlove
#执行脚本 delete_not_header_file.sh
#只保留 ./dlib 目录下的 .h 文件，其它类型文件将被删除
find ./dlib -type f -not -name '*.h' -delete
