package com.example.hypertracedemo.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

import com.example.hypertracedemo.model.User;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
public class KafkaConsumerService {

    private final Logger logger = LoggerFactory.getLogger(KafkaConsumerService.class);
    private final ObjectMapper objectMapper = new ObjectMapper();

    @KafkaListener(topics = "user-events", groupId = "user-group")
    public void consume(String userJson) {
        try {
            User user = objectMapper.readValue(userJson, User.class);
            logger.info(String.format("#### -> Consumed message -> %s", user));
        } catch (JsonProcessingException e) {
            logger.error("Error deserializing message: " + userJson, e);
        }
    }
}
