# Procedure for a CPAN release
---

## FINALIZE DEVELOPMENT
* finalize dev branch merges
* check for debug code in modules
* Modify Changelog
* Add missing authors to dist.ini (use `git shortlog -s -n -e` and select everyone with at least 2 commits or `git shortlog -s -n -e | awk '$1 >= 2 {printf "author  = %s\n", substr($0,index($0,$2))}' | sort`)
* Update htdocs/index.html (Sourceforge project home page)
* push all commits up to github
* dzil build - build a new release
* dzil test - test it out

## RELEASE

In order to upload files to PAUSE/CPAN and Sourceforge, the team member must have accounts with the proper privileges on those services. For PAUSE that is co-maint and for Sourceforge the user must be in the Admin group.

* Before executing `dzil release` confirm the git configuration settings `user.name` and `user.email` are set.
* dzil release - upload to cpan, tweet and mail :)
* upload module tarball to sourceforge @ https://sourceforge.net/projects/finance-quote/files/finance-quote/
    * Through Web interface
    * Or sftp \<SourceForge ID\>@frs.sourceforge.net
        * cd /home/frs/project/finance-quote/finance-quote
        * put Finance-Quote-N.NN.tar.gz
        * bye
* Upload index.html for http://finance-quote.sourceforge.net/index.html
    * sftp \<SourceForge ID\>,finance-quote@web.sourceforge.net
        * cd /home/project-web/finance-quote/htdocs
        * put index.html
        * bye

