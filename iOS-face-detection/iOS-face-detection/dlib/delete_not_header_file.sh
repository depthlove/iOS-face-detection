# 只保留 ./dlib 目录下的 .h 文件，其它类型文件将被删除
find ./dlib -type f -not -name '*.h' -delete
