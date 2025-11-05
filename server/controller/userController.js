const {query} = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

//register biasa menggunakan email dan password
exports.register = async (req, res) =>{
    const { username, email, password } = req.body;
    try {
        const emailExist = await query(`SELECT id_user FROM users_table WHERE email = $1`,[email])
        if(emailExist.rows.length > 0){
            return res.status(400).json({
                message:`Email already registered`
            })
        }

        const userExist = await query(`SELECT id_user FROM users_table WHERE name = $1`,[username])
        if(userExist.rows.length > 0){
            return res.status(400).json({
                message:`Username already registered`
            })
        }
        const hashedPassword = await bcrypt.hash(password, 10);
        await query(`
            INSERT INTO users_table 
            (name, email, password) 
            VALUES ($1, $2, $3) 
            `,[username, email, hashedPassword
        ])

        res.status(201).json({
            message:"user berhasil terdaftar"
        })
        
        
    } catch (error) {
        console.error("Error ketika melakukan registrasi user menggunakan email biasa", error);
        res.status(500).json({
            message: "Internal Server Error"
        })   
    }
}

//login biasa menggunakan email dan password
exports.login = async(req, res) =>{
    const { email, password} = req.body

    try {
        const user = await query(`SELECT * FROM users_table WHERE email = $1`,[email])

        if(user.rows.length === 0){
            return res.status(404).json({
                message:"User belum terdaftar, register dulu wak"
            })
        }

        const token = jwt.sign({
            email: email
        }, process.env.JWT_SECRET, {expiresIn: '1h'})


        const isPasswordValid = await bcrypt.compare(password, user.rows[0].password);
        if(!isPasswordValid){
            return res.status(401).json({
                message:"gagal melakukan login, password salah"
            })
        } else {
            return res.status(200).json({
                message:"berhasil login",
                token: token
            })
        }
    } catch (error) {
        console.error("Error ketika melakukan login user menggunakan email biasa", error)
        res.status(500).json({
            message:"Internal Server Error"
        })
        
    }
}

//masukin data age, height, weight

exports.updateProfileInfo = async(req, res) =>{
    const { age, height, weight, profile_picture} = req.body
    const { id_user } = req.user;
    
    try {
        const updatedFields = {};
        const checkUser = await query(`
            SELECT username 
            FROM users_table 
            WHERE id = $1
        `,[id_user])

        if(checkUser.rows.length === 0 ){
            return res.status(404).json({
                message:"User not found"
            })
        } 

        if(age) updatedFields.age = age;
        if(height) updatedFields.height = height;
        if(weight) updatedFields.weight = weight;

        const setFields = Object.keys(updatedFields).map((key,index) => `${key} =$${index+1}`).join(',');
        const values = Object.values(updatedFields)


        await query(`
            UPDATE users_table SET ${setFields} WHERE id_user = $${values.length + 1}    
        `,[...values, id_user])

        return res.status(200).json({
            message:"Sukses melakukan update data"
        })
        
    } catch (error) {
        console.error("Error ketika mengupdate info user",error)
        return res.status(500).json({
            message:"Internal Server Error"
        })
    }
}