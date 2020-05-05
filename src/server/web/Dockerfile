FROM python:3.8

WORKDIR /opt/cassh

COPY requirements.txt ./

RUN pip install --no-cache-dir -U pip

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD [ "python", "./cassh_web.py" ]
