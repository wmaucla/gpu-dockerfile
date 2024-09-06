# gpu-dockerfile


```docker
docker build -t bleh .
docker run --gpus all -it bleh poetry run python ltr.py
```