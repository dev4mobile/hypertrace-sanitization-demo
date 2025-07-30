deploy:
	docker-compose down -v
	docker-compose up -d --build

logs: deploy
	docker-compose logs -f hypertrace-demo-app 2>&1
