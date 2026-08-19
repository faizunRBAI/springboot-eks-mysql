package com.example.springbooteksmysql.controller;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class InfoController {

    @Value("${spring.application.name}")
    private String appName;

    /** Custom /api/info endpoint — verified by the pipeline's health-check step. */
    @GetMapping("/api/info")
    public Map<String, String> info() {
        return Map.of(
            "app", appName,
            "status", "ok"
        );
    }

    /** Simple /health endpoint for NLB target-group health checks (non-actuator path). */
    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP");
    }
}
