#
# Background worker that loads statistics from the Api-Gateway endpoint and sends them to StatsD.
# Designed to be restarted every minute by a cronjob
#
import json, sys, socket, urllib2
import argparse
from threading import Timer

class StatsCollectorWorker:

    UDP_MAX_BUFFER_SIZE = 800

    def __init__(self, statsRestEndpoint, statsd_host, statsd_port ):
        print(("Starting collecting form [%s], sending to StatsD on [%s:%s]") % (gateway_uri, statsd_host, statsd_port) )
        self.statsRestEndpoint = statsRestEndpoint
        self.statsd_host = statsd_host
        self.statsd_port = statsd_port
        self.udp_buffer = ""

    def getStatsFromUrl(self, url):
        try:
            stats_txt = urllib2.urlopen(url).read()
            return json.loads(stats_txt)
        except Exception as e:
            print "Could not read stats", e
            return None

    def flushBuffer(self):
        # print "Sending:", self.udp_buffer
        self.udp_sock.send(self.udp_buffer)
        self.udp_buffer = ''

    def sentStatsFromCollection(self, metricCollection, metricType):
        for i, item in enumerate(metricCollection):
            # print i, item, metricCollection[item]
            statsd_metric = ('%s:%s|%s' % (item, metricCollection[item],metricType)).encode("utf-8")
            if self.udp_buffer.__len__() + statsd_metric.__len__() > StatsCollectorWorker.UDP_MAX_BUFFER_SIZE:
                self.flushBuffer()
            self.udp_buffer = ''.join([self.udp_buffer, "\n", statsd_metric])

    def sendStats(self, obj):
        # TODO: split statsd_host by space in order to support sending data to multiple statsd backends
        try:
            self.udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.udp_sock.connect((self.statsd_host, self.statsd_port))
        except Exception as e:
            print "Could not connect to StatsD", e
            return None
        try:
            self.sentStatsFromCollection(obj["timers"], "ms")
            self.sentStatsFromCollection(obj["counters"], "c")
            if self.udp_buffer.__len__() > 0:
                self.flushBuffer()
        except Exception as e:
            print "Could not send statistics", e
        self.udp_sock.close()

    def getAndSendStats(self,nextInterval, maxRuns):
        # Read the JSON from the gateway's endpoint
        # TODO: add an exception in case JSON conversion fails
        obj = self.getStatsFromUrl(self.statsRestEndpoint)
        if obj is not None:
            self.sendStats(obj)

        # print ("Stats processed. %s runs left" % (maxRuns))
        if maxRuns <= 0:
            return None
        t = Timer(nextInterval, self.getAndSendStats, [nextInterval, maxRuns - 1])
        t.start()


statsd_host = "api-gateway-graphite"
statsd_port = int("8125")
gateway_uri = "http://127.0.0.1/api-gateway-stats"
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--statsd-host', dest='statsd_host', required=True)
    parser.add_argument('-p', '--statsd-port', dest='statsd_port')
    parser.add_argument('-g', '--gateway-uri', dest='gateway_uri')
    args = parser.parse_args()
    statsd_host = args.statsd_host or statsd_host
    statsd_port = int(args.statsd_port or statsd_port)
    gateway_uri = args.gateway_uri or gateway_uri

collector = StatsCollectorWorker(statsRestEndpoint=gateway_uri, statsd_host=statsd_host, statsd_port=statsd_port)
# set the collector to run each 3 seconds , max 18 times
collector.getAndSendStats(nextInterval=3,maxRuns=18)

# Sample StatsD messages
# pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.device_links.POST.200.count
# pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.device_links.POST.200.responseTime
# pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.device_links.POST.200.upstreamResponseTime
# pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.validate_request.GET.200.responseTime
