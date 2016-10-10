# vklimovs' personal portage overlay

## Adding overlay

To add overlay run:
> layman -o https://raw.githubusercontent.com/vklimovs/portage-overlay/master/repository.xml -f -a vklimovs

```
To avoid layman warnings about missing remote overlay add repository.xml to list overlays, like so:

#            file:///var/lib/layman/my-list.xml

overlays  : http://www.gentoo.org/proj/en/overlays/repositories.xml
            https://raw.githubusercontent.com/vklimovs/portage-overlay/master/repository.xml

#-----------------------------------------------------------
```

## Things of note

Following nfsen bugs are fixed by patches provided in the ebuild:

* PHP undefined variable:

Undefined variable: chan_id in /var/www/localhost/htdocs/nfsen/profileadmin.php on line 593
  Undefined variable: chan_id in /var/www/localhost/htdocs/nfsen/profileadmin.php on line 594

* Socket6 module changes and use of whois:
Subroutine Lookup::pack_sockaddr_in6 redefined at /usr/lib64/perl5/vendor_perl/5.22.2/nfsen/Lookup.pm line 43
Subroutine Lookup::unpack_sockaddr_in6 redefined at /usr/lib64/perl5/vendor_perl/5.22.2/nfsen/Lookup.pm line 43
Subroutine Lookup::sockaddr_in6 redefined at /usr/lib64/perl5/vendor_perl/5.22.2/nfsen/Lookup.pm line 43
Subroutine AbuseWhois::pack_sockaddr_in6 redefined at /usr/lib64/perl5/vendor_perl/5.22.2/nfsen/AbuseWhois.pm line 42
Subroutine AbuseWhois::unpack_sockaddr_in6 redefined at /usr/lib64/perl5/vendor_perl/5.22.2/nfsen/AbuseWhois.pm line 42
Subroutine AbuseWhois::sockaddr_in6 redefined at /usr/lib64/perl5/vendor_perl/5.22.2/nfsen/AbuseWhois.pm line 42
Subroutine AbuseWhois::pack_sockaddr_in6 redefined at /usr/share/nfsen/libexec/AbuseWhois.pm line 44
Subroutine AbuseWhois::unpack_sockaddr_in6 redefined at /usr/lib64/perl5/vendor_perl/5.22.2/nfsen/AbuseWhois.pm line 44
Subroutine AbuseWhois::sockaddr_in6 redefined at /usr/lib64/perl5/vendor_perl/5.22.2/nfsen/AbuseWhois.pm line 44



