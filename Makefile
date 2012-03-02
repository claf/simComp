APPS=simple complex ended mjpeg decoder

test:
	$(foreach app,$(APPS),$(shell ./simu.pl -t 1000 -c 8 -p 1 apps/$(app).sim $(app)_np.trace))
	$(foreach app,$(APPS),$(shell ./simu.pl -t 1000 -c 8 -p 10 apps/$(app).sim $(app).trace))
	$(foreach app,$(APPS),$(shell diff -q $(app)_np.trace apps/$(app)_np.trace))
	$(foreach app,$(APPS),$(shell diff -q $(app).trace apps/$(app).trace))

clean:
	rm -rf log.txt *~ apps/*~

veryclean:clean
	rm -rf *trace
