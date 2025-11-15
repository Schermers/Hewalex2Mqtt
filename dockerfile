FROM python:3.7-alpine

COPY ./requirements.txt /requirements.txt
RUN pip3 install -r /requirements.txt && rm requirements.txt

ENTRYPOINT [ "python3", "/hewagate/hewalex2mqtt.py" ]
