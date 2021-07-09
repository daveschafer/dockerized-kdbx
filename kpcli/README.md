# Interactive KPCLI (KeePass CLI) in container

Simple usage:

```
sudo docker build -t docker-kpcli2 .
sudo docker run -it --rm -v /home/me:/data docker-kpcli2:latest
```

Within KPCLI:

```
saveas secrets.kdbx
>>enter master password
quit
```
