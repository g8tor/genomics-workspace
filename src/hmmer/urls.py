from hmmer import views
from django.urls import re_path

app_name='hmmer'
urlpatterns = [
    # ex: /hmmer/
    re_path(r'^$', views.create, name='create'),
    # ex: /hmmer/task/5/
    re_path(r'^task/(?P<task_id>[0-9a-zA-Z]+)$', views.retrieve, name='retrieve'),
    re_path(r'^task/(?P<task_id>[0-9a-zA-Z]+)/status$', views.status, name='status'),
    re_path(r'^manual/$', views.manual, name='manual'),
]
