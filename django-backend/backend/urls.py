"""
URL configuration for backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.urls import path, include
from django.contrib import admin

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('account.urls')),
    path('api/blood-requests/', include('blood_requests.urls')),
    path('api/blood-types/', include('blood_types.urls')),
    path('api/donations/', include('donations.urls')),
    path('api/sos/', include('sos.urls')),
    path('api/stats/', include('stats.urls')),
    path('api/health/', include('health.urls')),
    path('api/notifications/', include('notifications.urls')),
    # Phase 8: Chat System
    path('api/chat/', include('chat.urls')),
    # Admin endpoints
    path('api/admin/', include('account.admin_urls')),
    path('api/admin/stats/', include('stats.admin_urls')),
]

# Admin blood requests endpoints (added separately to avoid module import issues)
from blood_requests.urls import admin_urlpatterns
urlpatterns += [
    path('api/admin/blood-requests/', include((admin_urlpatterns, 'blood_requests'), namespace='admin_blood_requests')),
]
