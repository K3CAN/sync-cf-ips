  This script will download the current IPv4 addresses used by cloudflare and create/update NGINX's "real_ip" configuration so that the source IPs are recorded correctly in the log. 
  
  It assumes you're using NGINX's config.d, and creates or replaces a "real_ips.conf" file into that directory. 

  This is intended to ensure that nginx correctly logs the originating IP when incoming connections are proxied through cloudflare proxy service. 