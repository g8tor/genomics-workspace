from django.conf.urls import url
from django.conf import settings
from blast import views

app_name='blast'
urlpatterns = [
    # ex: /blast/
    url(r'^$', views.create, name='create'),
    url(r'^task/(?P<task_id>[0-9a-zA-Z]+)$', views.retrieve, name='retrieve'),
    url(r'^task/(?P<task_id>[0-9a-zA-Z]+)/status$', views.status, name='status'),
    url(r'^manual/$', views.manual, name='manual'),
]

if settings.DEBUG:
    from blast import test_views
    urlpatterns += [
        url(r'^test/$', test_views.test_main)
    ]
