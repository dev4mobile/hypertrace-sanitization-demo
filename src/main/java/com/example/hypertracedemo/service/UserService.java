package com.example.hypertracedemo.service;

import java.util.List;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.example.hypertracedemo.model.User;
import com.example.hypertracedemo.repository.UserRepository;

@Service
public class UserService {

    private static final Logger logger = LoggerFactory.getLogger(UserService.class);

    @Autowired
    private UserRepository userRepository;

    public List<User> getAllUsers() {
        logger.info("获取所有用户");
        return userRepository.findAll();
    }

    public User getUserById(Long id) {
        logger.info("根据ID获取用户: {}", id);
        Optional<User> user = userRepository.findById(id);
        return user.orElse(null);
    }

    public User createUser(User user) {
        logger.info("创建新用户: {}", user.getName());

        // 检查邮箱是否已存在
        if (userRepository.existsByEmail(user.getEmail())) {
            logger.error("邮箱已存在: {}", user.getEmail());
            throw new IllegalArgumentException("邮箱已存在");
        }

        User savedUser = userRepository.save(user);
        logger.info("用户创建成功，ID: {}", savedUser.getId());
        return savedUser;
    }

    public User updateUser(Long id, User user) {
        logger.info("更新用户: {}", id);

        Optional<User> existingUser = userRepository.findById(id);
        if (existingUser.isPresent()) {
            User userToUpdate = existingUser.get();
            userToUpdate.setName(user.getName());
            userToUpdate.setEmail(user.getEmail());
            userToUpdate.setPhone(user.getPhone());

            User updatedUser = userRepository.save(userToUpdate);
            logger.info("用户更新成功: {}", updatedUser.getId());
            return updatedUser;
        } else {
            logger.warn("用户不存在: {}", id);
            return null;
        }
    }

    public boolean deleteUser(Long id) {
        logger.info("删除用户: {}", id);

        if (userRepository.existsById(id)) {
            userRepository.deleteById(id);
            logger.info("用户删除成功: {}", id);
            return true;
        } else {
            logger.warn("用户不存在: {}", id);
            return false;
        }
    }
}
