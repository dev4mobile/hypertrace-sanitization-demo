package com.example.hypertracedemo.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import com.example.hypertracedemo.model.User;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
public class KafkaProducerService {

    private static final Logger logger = LoggerFactory.getLogger(KafkaProducerService.class);
    private static final String TOPIC = "user-events";

    @Autowired
    private KafkaTemplate<String, String> kafkaTemplate;

    @Autowired
    private ObjectMapper objectMapper;

    public void sendMessage(User user) {
        try {
            String userJson = objectMapper.writeValueAsString(user);
            logger.info(String.format("#### -> Producing message -> %s", userJson));
            this.kafkaTemplate.send(TOPIC, user.getId().toString(), userJson);
        } catch (JsonProcessingException e) {
            logger.error("Error serializing user object to JSON", e);
        }
    }
}
