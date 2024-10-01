from django.conf.urls import url
from clustal import views
from django.urls import  re_path

app_name='clustal'
urlpatterns = [
    # ex: /clustal/
    re_path(r'^$', views.create, name='create'),
    # ex: /clustal/5/
    re_path(r'^task/(?P<task_id>[0-9a-zA-Z]+)$', views.retrieve, name='retrieve'),
    re_path(r'^task/(?P<task_id>[0-9a-zA-Z]+)/status$', views.status, name='status'),
    re_path(r'^manual/$', views.manual, name='manual'),
]
