const express = require('express')
const router = express.Router();
const userController = require('../controller/userController')
const authenticate = require('../middleware/authenticate')

router.post('/emailRegis', userController.register);
router.post('/emailLogin', userController.login)
router.post('/updateProfileInfo', authenticate,userController.updateProfileInfo)

module.exports = router