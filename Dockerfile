FROM python:3.11-slim

WORKDIR /app

COPY bot/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY bot/ .

EXPOSE 8585

CMD ["python", "mindfocus_bot.py"]
