.PHONY: deploy
deploy:
	docker-compose down -v
	docker-compose up -d --build

.PHONY: logs
logs: deploy
	docker-compose logs -f hypertrace-demo-app 2>&1

.PHONY: push
push:
	git push origin master
