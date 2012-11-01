APPS=simple complex ended mjpeg decoder


clean:
	rm -rf log.txt *~ apps/*~

veryclean:clean
	rm -rf *trace

test:
	$(foreach app,$(APPS),$(shell ./simu.pl -f 0.0001 -t 1000 -c 4 -p 1 apps/$(app).sim $(app)_np.trace))
	$(foreach app,$(APPS),$(shell ./simu.pl -f 0.0001 -t 1000 -c 4 -p 10 apps/$(app).sim $(app).trace))
	$(foreach app,$(APPS),$(shell diff -q $(app)_np.trace apps/$(app)_np.trace))
	$(foreach app,$(APPS),$(shell diff -q $(app).trace apps/$(app).trace))
