FROM python:3-alpine

ENV FLASK_APP=app.py
ENV FLASK_ENV=development

WORKDIR /src/app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .

EXPOSE 80/tcp
CMD ["flask", "run", "--host=0.0.0.0", "--port=80"]

