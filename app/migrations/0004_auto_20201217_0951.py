# Generated by Django 2.2.14 on 2020-12-17 14:51

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0003_auto_20180521_1649'),
    ]

    operations = [
        migrations.AlterField(
            model_name='organism',
            name='display_name',
            field=models.CharField(help_text='Scientific or common name', max_length=200, unique=True),
        ),
        migrations.AlterField(
            model_name='organism',
            name='short_name',
            field=models.CharField(help_text='This is used for file names and variable names in code', max_length=20, unique=True),
        ),
        migrations.AlterField(
            model_name='organism',
            name='tax_id',
            field=models.PositiveIntegerField(blank=True, help_text='This is passed into makeblast', null=True, verbose_name='NCBI Taxonomy ID'),
        ),
    ]