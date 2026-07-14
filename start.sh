#!/bin/bash
cd django-backend && exec gunicorn backend.wsgi:application --bind 0.0.0.0:$PORT --workers 4 --threads 2 --worker-class gthread --worker-timeout 120 --timeout 120
