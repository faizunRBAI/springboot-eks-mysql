package com.example.springbooteksmysql.controller;

import com.example.springbooteksmysql.model.Item;
import com.example.springbooteksmysql.repository.ItemRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ItemControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ItemRepository itemRepository;

    @BeforeEach
    void setUp() {
        itemRepository.deleteAll();
    }

    @Test
    void listReturnsEmptyInitially() throws Exception {
        mockMvc.perform(get("/api/items"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$", hasSize(0)));
    }

    @Test
    void createAndRetrieveItem() throws Exception {
        mockMvc.perform(post("/api/items")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"widget\",\"description\":\"a test widget\"}"))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.name", is("widget")));

        mockMvc.perform(get("/api/items"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$", hasSize(1)));
    }

    @Test
    void createItemWithoutNameReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/items")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"description\":\"no name\"}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void getByIdReturnsNotFoundForMissing() throws Exception {
        mockMvc.perform(get("/api/items/999999"))
            .andExpect(status().isNotFound());
    }

    @Test
    void deleteItem() throws Exception {
        Item saved = itemRepository.save(new Item("to-delete", "desc"));

        mockMvc.perform(delete("/api/items/" + saved.getId()))
            .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/items/" + saved.getId()))
            .andExpect(status().isNotFound());
    }
}
