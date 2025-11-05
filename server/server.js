require("dotenv").config();
const express = require("express");
const app = express();
const db = require("./db")
const multer = require("multer");
const cors = require("cors");
const cookieParser = require('cookie-parser');

app.use(express.json());
app.use(cookieParser());

const corsOptions = {
  origin: "http://localhost:5173", 
  methods: ["GET", "POST", "PUT", "DELETE","OPTIONS"], 
  credentials: true,
};

const userRoutes = require('./router/userRouter')

app.use('/api/v1/users', userRoutes);

app.use(express.urlencoded({extended: true}));


app.use(cors(corsOptions))


app.use((req,res,next) => {
    res.status(404).json({ error: "API Route Not Found"})
})

const PORT = process.env.PORT || 5050;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});