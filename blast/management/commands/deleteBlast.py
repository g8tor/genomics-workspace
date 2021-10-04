from blast.models import BlastDb
from django.core.management.base import BaseCommand
import os.path
from django.core.exceptions import ObjectDoesNotExist
import pdb 
import sys

class Command(BaseCommand):

    def add_arguments(self,parser):
        parser.add_argument('blastdb_id',type=int)

    def handle(self,*args,**options):

        try:
            blastdb_id = options['blastdb_id']
            db = BlastDb.objects.with_counts().filter(pk=blastdb_id)[0]
            print (f"""
             Database Located:
             id: {db.pk}
             title: {db.title}

             Deleting This Database Will also delete the folowing related objects:

             JbrowseSetting Records: {db.num_jbrowsesettings}
             Sequence Records: {db.num_sequences}

            """)

            delete = input("Are you sure you want to delete this database?[y,N]:") or "N"
            if delete.lower() != "y":
                print(f"Abort: The Blast Database with id {db.pk} will NOT be deleted.")
                sys.exit(0)
            else:
                print(f"Deleteing Blast Database with id {db.pk}") 
                db.delete()
                try:
                    BlastDb.objects.get(id=blastdb_id)
                except ObjectDoesNotExist as nono:
                    print(f"Blast Database with id {blastdb_id} successfully deleted")
                    sys.exit(0)

        except (ObjectDoesNotExist, IndexError) as nono:
            print(f"Sorry A database with the id {blastdb_id} does not exist.")
            sys.exit(1)

        pdb.set_trace()
